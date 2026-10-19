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
              interfaces = [
                {
                  # User-mode networking requires no root/sudo privileges on the host
                  type = "user";
                  id = "vm-t1";
                  mac = "02:00:00:00:00:01";
                }
              ];
            };

            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];

            services.getty.autologinUser = "root";

            services.github-runners.gh-runner-org-arntanguy-sandbox = {
              enable = true;
              url = "https://github.com/arntanguy-sandbox";
              tokenFile =
                let
                  tf = config.sops.secrets.arntanguy-sandbox-github_token.path;
                in
                builtins.trace "using tokenFile ${tf}" tf;
              runnerGroup = "lirmm_private";
              replace = true;
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

            systemd.services."github-runner-gh-runner-org-arntanguy-sandbox".serviceConfig.ExecStopPost =
              "${pkgs.systemd}/bin/poweroff";

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
              interfaces = [
                {
                  # User-mode networking requires no root/sudo privileges on the host
                  type = "user";
                  id = "vm-t1";
                  mac = "02:00:00:00:00:01";
                }
              ];
            };

            services.getty.autologinUser = "root";

            services.github-runners.gh-runner-org-isri-aist = {
              enable = true;
              url = "https://github.com/isri-aist";
              tokenFile = config.sops.secrets.isri-aist-github_token.path;
              tokenType = "registration";
              runnerGroup = "lirmm_private";
              replace = true;
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
