{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.services.nixGhaRunner;
  instance = toString cfg.instanceNumber;
  derivedRunnerName = "gh-runner-org-${cfg.organization}-${cfg.hostName}-${instance}";
  runnerName = if cfg.runnerName == null then derivedRunnerName else cfg.runnerName;
  volumeDirectory = "${cfg.volumeDirectory}/${runnerName}";
  networkHash = builtins.hashString "sha256" "${cfg.organization}:${cfg.hostName}:${instance}";
  derivedMacAddress = "02:${builtins.substring 0 2 networkHash}:${
    builtins.substring 2 2 networkHash
  }:${builtins.substring 4 2 networkHash}:${builtins.substring 6 2 networkHash}:${
    builtins.substring 8 2 networkHash
  }";
in
{
  imports = [ ./secrets.nix ];

  options.services.nixGhaRunner = {
    enable = lib.mkEnableOption "an ephemeral GitHub Actions runner MicroVM";

    organization = mkOption {
      type = types.str;
      description = "GitHub organization served by this runner.";
    };

    instanceNumber = mkOption {
      type = types.ints.positive;
      default = 1;
      description = "Positive number identifying this VM instance.";
    };

    hostName = mkOption {
      type = types.str;
      default = "local";
      description = "Host identity included in the generated runner name.";
    };

    sshPublicKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Public key authorized for root SSH access to the guest.";
    };

    sshHostPort = mkOption {
      type = types.nullOr types.port;
      default = null;
      description = "Loopback host port forwarded to guest SSH.";
    };

    runnerName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "GitHub runner name. Defaults to an organization, host, and instance-derived name.";
    };

    runnerUser = mkOption {
      type = types.str;
      default = "github-runner";
      description = "System user that runs the GitHub runner.";
    };

    runnerGroup = mkOption {
      type = types.str;
      default = "github-runner";
      description = "System group that runs the GitHub runner.";
    };

    tokenSecret = mkOption {
      type = types.str;
      description = "Name of the SOPS secret containing the GitHub runner token.";
    };

    runnerGroupName = mkOption {
      type = types.str;
      default = "Default";
      description = "GitHub runner group.";
    };

    extraLabels = mkOption {
      type = types.listOf types.str;
      default = [
        "nix"
        "docker"
      ];
      description = "Additional GitHub runner labels.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        git
        gnumake
        gcc
        nix
        bash
        coreutils
        cachix
        attic-client
        openssh
      ];
      description = "Packages available to GitHub Actions jobs.";
    };

    replace = mkOption {
      type = types.bool;
      default = true;
      description = "Replace a pre-existing GitHub runner registration.";
    };

    ephemeral = mkOption {
      type = types.bool;
      default = true;
      description = "Use an ephemeral GitHub runner.";
    };

    volumeDirectory = mkOption {
      type = types.str;
      default = "volumes";
      description = "Directory containing VM-persistent volume images.";
    };

    writableStoreOverlay = mkOption {
      type = types.str;
      default = "/nix/.rw-store";
      description = "Guest mount point for the writable Nix store overlay.";
    };

    writableStoreOverlaySize = mkOption {
      type = types.ints.positive;
      default = 20000;
      description = "Writable Nix store overlay size in MiB.";
    };

    ccacheDirectory = mkOption {
      type = types.str;
      default = "/var/cache/ccache";
      description = "Guest directory used for the persistent ccache volume.";
    };

    ccacheVolumeSize = mkOption {
      type = types.ints.positive;
      default = 5000;
      description = "Persistent ccache volume size in MiB.";
    };

    hypervisor = mkOption {
      type = types.str;
      default = "qemu";
      description = "MicroVM hypervisor.";
    };

    memory = mkOption {
      type = types.ints.positive;
      default = 16384;
      description = "MicroVM memory allocation in MiB.";
    };

    interfaceId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "User-mode network interface identifier.";
    };

    macAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "User-mode network MAC address.";
    };

    ageKeyDirectory = mkOption {
      type = types.str;
      default = "/home/arnaud/.config/sops/age";
      description = "Host directory shared read-only to provide the SOPS age key.";
    };

    enableCcache = mkOption {
      type = types.bool;
      default = true;
      description = "Enable ccache in the guest.";
    };

    shutdownCommand = mkOption {
      type = types.str;
      default = "+${pkgs.systemd}/bin/poweroff -f";
      description = "Command run after the GitHub runner service stops.";
    };

    systemStateVersion = mkOption {
      type = types.str;
      default = "26.04";
      description = "NixOS state version for the guest.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.sshPublicKey == null) == (cfg.sshHostPort == null);
        message = "services.nixGhaRunner.sshPublicKey and sshHostPort must be configured together.";
      }
    ];

    microvm = {
      inherit (cfg) hypervisor;
      mem = cfg.memory;
      interfaces = [
        {
          type = "user";
          id =
            if cfg.interfaceId == null then "vm-${builtins.substring 0 12 networkHash}" else cfg.interfaceId;
          mac = if cfg.macAddress == null then derivedMacAddress else cfg.macAddress;
        }
      ];
      inherit (cfg) writableStoreOverlay;
      forwardPorts = lib.optional (cfg.sshHostPort != null) {
        from = "host";
        proto = "tcp";
        host = {
          address = "127.0.0.1";
          port = cfg.sshHostPort;
        };
        guest.port = 22;
      };
      volumes = [
        {
          image = "${volumeDirectory}/nix-store-overlay.img";
          mountPoint = cfg.writableStoreOverlay;
          size = cfg.writableStoreOverlaySize;
        }
        {
          image = "${volumeDirectory}/ccache-dir-overlay.img";
          mountPoint = cfg.ccacheDirectory;
          size = cfg.ccacheVolumeSize;
        }
      ];
    };

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        cfg.runnerUser
      ];
      extra-sandbox-paths = [ config.programs.ccache.cacheDir ];
    };

    users.users.${cfg.runnerUser} = {
      isSystemUser = true;
      group = cfg.runnerGroup;
      home = "/run/github-runner/${runnerName}";
      createHome = true;
    };
    users.groups.${cfg.runnerGroup} = { };

    virtualisation.docker.enable = true;
    programs.ccache.enable = cfg.enableCcache;
    services.getty.autologinUser = "root";
    services.openssh = lib.mkIf (cfg.sshPublicKey != null) {
      enable = true;
      settings.PermitRootLogin = "prohibit-password";
    };
    users.users.root.openssh.authorizedKeys.keys = lib.optional (
      cfg.sshPublicKey != null
    ) cfg.sshPublicKey;
    networking.firewall.allowedTCPPorts = lib.optional (cfg.sshHostPort != null) 22;

    services.github-runners.${runnerName} = {
      enable = true;
      user = cfg.runnerUser;
      group = cfg.runnerGroup;
      url = "https://github.com/${cfg.organization}";
      tokenFile = config.sops.secrets.${cfg.tokenSecret}.path;
      runnerGroup = cfg.runnerGroupName;
      inherit (cfg)
        extraLabels
        replace
        ephemeral
        extraPackages
        ;
    };

    systemd.services."github-runner-${runnerName}" = {
      path = [ pkgs.systemd ];
      serviceConfig.ExecStopPost = cfg.shutdownCommand;
    };

    system.stateVersion = cfg.systemStateVersion;
  };
}
