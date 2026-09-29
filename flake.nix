{
  description = "On-demand MicroVM GitHub Action Runner with SOPS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microvm, sops-nix }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      microvmConfigurations.gh-runner-org-isri-aist = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          microvm.nixosModules.microvm
          sops-nix.nixosModules.sops
          ({ pkgs, config, ... }: {
            sops = {
              defaultSopsFile = ./secrets/secrets.yaml;
              age.keyFile = "/var/lib/sops-nix/key.txt";
              secrets.isri-aist-github_token = {
                key = "isri-aist/github_token";
                mode = "0400";
                owner = "root";
              };
            };

            microvm = {
              hypervisor = "cloud-hypervisor";
              # Mount host age key into guest read-only
              shares = [
                {
                  source = "/home/arnaud/.config/sops/age/keys.txt";    # Path on host
                  mountPoint = "/var/lib/sops-nix/key.txt";# Path inside guest
                  tag = "sops-key";
                  proto = "virtiofs";
                  socket = "/tmp/sops-key.sock";
                  readOnly = true;                          # Enforces read-only access
                }
              ];

            };

            services.getty.autologinUser = "root";

            services.github-runners.gh-runner-org-isri-aist = {
              enable = true;
              url = "https://github.com/isri-aist";
              tokenFile = config.sops.secrets.isri-aist-github_token.path;
              ephemeral = true;
              extraPackages = with pkgs; [
                git
                gnumake
                gcc
                nix
                bash
                coreutils
              ];
            };

            systemd.services."github-runner-gh-runner-org-isri-aist".serviceConfig.ExecStopPost =
              "${pkgs.systemd}/bin/poweroff";

            system.stateVersion = "24.05";
          })
        ];
      };

apps.${system}.gh-runner-org-isri-aist = {
  type = "app";
  program = let
    # Extract the runner package directly from the evaluated VM config:
    runner = self.microvmConfigurations.gh-runner-org-isri-aist.config.microvm.declaredRunner;
  in "${pkgs.writeShellScriptBin "run-microvm" ''
    rm -f /tmp/sops-key.sock
    export PATH="${pkgs.virtiofsd}/bin:$PATH"
    exec ${runner}/bin/microvm-run "$@"
  ''}/bin/run-microvm";
};
    };
}
