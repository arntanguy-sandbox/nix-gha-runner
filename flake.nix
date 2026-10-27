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

    # Treefmt framework integration
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
      treefmt-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      treefmtEval = treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
        projectRootFile = "flake.nix";

        # Configure the formatters you want to use
        programs.nixfmt.enable = true; # Formatter for Nix files
        programs.mdformat.enable = true; # Formatter for Markdown files
      };
    in
    {
      microvmConfigurations.gh-runner-org-arntanguy-sandbox = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
        };
        modules = [
          microvm.nixosModules.microvm
          ({ pkgs, config, ... }: {
            microvm = {
              hypervisor = "qemu"; # User-mode networking requires QEMU
              mem = 16384; # 16Go RAM allocation
              interfaces = [
                {
                  # User-mode networking requires no root/sudo privileges on the host
                  type = "user";
                  id = "vm-t1";
                  mac = "02:00:00:00:00:01";
                }
              ];
              # An optional writable layer will be mounted if the path microvm.writableStoreOverlay is set. Make sure that the path is located on a writable filesystem.
              # Caveat: The Linux overlay filesystem is very picky about the filesystems that can be the upper (writable) layer. 9p/virtiofs shares don’t work currently, so resort to using a volume for that:
              writableStoreOverlay = "/nix/.rw-store";
              volumes = [
                {
                  image = "volumes/nix-store-overlay-gh-runner-org-arntanguy-sandbox.img";
                  mountPoint = config.microvm.writableStoreOverlay;
                  size = 20000; # Mb
                }
              ];

            };

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];
            nix.settings.trusted-users = [
              "root"
              "github-runner"
            ];

            nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];

            # Explicitly create the system user and group ---
            users.users.github-runner = {
              isSystemUser = true;
              group = "github-runner";
              home = "/run/github-runner/gh-runner-org-isri-aist";
              createHome = true;
            };
            users.groups.github-runner = { };

            virtualisation.docker.enable = true;

            services.getty.autologinUser = "root";

            services.github-runners.gh-runner-org-arntanguy-sandbox = {
              enable = true;
              # Force a predictable static username instead of a dynamic user
              user = "github-runner";
              group = "github-runner";
              url = "https://github.com/arntanguy-sandbox";
              tokenFile =
                let
                  tf = config.sops.secrets.arntanguy-sandbox-github_token.path;
                in
                builtins.trace "using tokenFile ${tf}" tf;
              runnerGroup = "Default";
              extraLabels = [
                "nix"
                "docker"
              ];
              replace = true;
              ephemeral = true;
              extraPackages = with pkgs; [
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
            };

            systemd.services."github-runner-gh-runner-org-arntanguy-sandbox".serviceConfig = {
              ExecStopPost = "+poweroff -f";
              # Make sure util-linux (which provides poweroff) is in the PATH for this service
              path = [ pkgs.util-linux ];
            };

            system.stateVersion = "26.04";

          })
          ./modules/secrets.nix
        ];
      };
      microvmConfigurations.gh-runner-org-isri-aist = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
        };
        modules = [
          microvm.nixosModules.microvm
          ({ pkgs, config, ... }: {
            microvm = {
              hypervisor = "qemu"; # User-mode networking requires QEMU
              mem = 16384; # 16Go RAM allocation
              interfaces = [
                {
                  # User-mode networking requires no root/sudo privileges on the host
                  type = "user";
                  id = "vm-t1";
                  mac = "02:00:00:00:00:01";
                }
              ];
              # An optional writable layer will be mounted if the path microvm.writableStoreOverlay is set. Make sure that the path is located on a writable filesystem.
              # Caveat: The Linux overlay filesystem is very picky about the filesystems that can be the upper (writable) layer. 9p/virtiofs shares don’t work currently, so resort to using a volume for that:
              writableStoreOverlay = "/nix/.rw-store";
              volumes = [
                {
                  image = "volumes/nix-store-overlay-gh-runner-org-isri-aist.img";
                  mountPoint = config.microvm.writableStoreOverlay;
                  size = 20000; # Mb
                }
              ];

            };

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];
            nix.settings.trusted-users = [
              "root"
              "github-runner"
            ];

            nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];
            nixpkgs.overlays = [
              (self: super: {
                ccacheWrapper =
                  builtins.trace "ccache directory: ${config.programs.ccache.ccacheDir}" super.ccacheWrapper.override
                    {
                      extraConfig = ''
                        export CCACHE_COMPRESS=1
                        export CCACHE_DIR="${config.programs.ccache.cacheDir}"
                        export CCACHE_UMASK=007
                        export CCACHE_SLOPPINESS=random_seed
                        if [ ! -d "$CCACHE_DIR" ]; then
                          echo "====="
                          echo "Directory '$CCACHE_DIR' does not exist"
                          echo "Please create it with:"
                          echo "  sudo mkdir -m0770 '$CCACHE_DIR'"
                          echo "  sudo chown root:nixbld '$CCACHE_DIR'"
                          echo "====="
                          exit 1
                        fi
                        if [ ! -w "$CCACHE_DIR" ]; then
                          echo "====="
                          echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
                          echo "Please verify its access permissions"
                          echo "====="
                          exit 1
                        fi
                      '';
                    };
              })
            ];

            # Explicitly create the system user and group ---
            users.users.github-runner = {
              isSystemUser = true;
              group = "github-runner";
              home = "/run/github-runner/gh-runner-org-isri-aist";
              createHome = true;
            };
            users.groups.github-runner = { };

            virtualisation.docker.enable = true;

            services.getty.autologinUser = "root";

            services.github-runners.gh-runner-org-isri-aist = {
              enable = true;
              # Force a predictable static username instead of a dynamic user
              user = "github-runner";
              group = "github-runner";
              url = "https://github.com/isri-aist";
              tokenFile =
                let
                  tf = config.sops.secrets.isri-aist-github_token.path;
                in
                builtins.trace "using tokenFile ${tf}" tf;
              runnerGroup = "Default";
              extraLabels = [
                "nix"
                "docker"
              ];
              replace = true;
              ephemeral = true;
              extraPackages = with pkgs; [
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
            };

            systemd.services."github-runner-gh-runner-org-isri-aist".serviceConfig = {
              ExecStopPost = "+poweroff -f";
              # Make sure util-linux (which provides poweroff) is in the PATH for this service
              path = [ pkgs.util-linux ];
            };

            system.stateVersion = "26.04";

          })
          ./modules/secrets.nix
        ];
      };

      packages.${system} = {
        gh-runner-org-isri-aist =
          self.microvmConfigurations.gh-runner-org-isri-aist.config.microvm.declaredRunner;
        gh-runner-org-arntanguy-sandbox =
          self.microvmConfigurations.gh-runner-org-arntanguy-sandbox.config.microvm.declaredRunner;
      };
      # Expose the formatter wrapper to the flake outputs
      formatter.${system} = treefmtEval.config.build.wrapper;
    };
}
