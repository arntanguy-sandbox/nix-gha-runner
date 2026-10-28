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
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      microvm,
      treefmt-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
        programs.mdformat.enable = true;
      };

      organizationModules = {
        arntanguy-sandbox = ./modules/orgs/arntanguy-sandbox.nix;
        isri-aist = ./modules/orgs/isri-aist.nix;
      };

      mkRunnerConfiguration =
        {
          organization,
          instanceNumber ? 1,
          hostName ? "local",
          sshPublicKey ? null,
          sshHostPort ? null,
          extraModules ? [ ],
        }:
        let
          organizationModule =
            if builtins.hasAttr organization organizationModules then
              organizationModules.${organization}
            else
              throw "Unsupported GitHub organization: ${organization}";
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            microvm.nixosModules.microvm
            ./modules/runner.nix
            organizationModule
            {
              services.nixGhaRunner = {
                inherit
                  instanceNumber
                  hostName
                  sshPublicKey
                  sshHostPort
                  ;
              };
            }
          ]
          ++ extraModules;
        };

      mkRunnerLauncher =
        organization:
        pkgs.writeShellApplication {
          name = "gh-runner-org-${organization}";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.inetutils
            pkgs.nix
            pkgs.openssh
            pkgs.virtiofsd
          ];
          text = ''
            if [[ ! -x "$PWD/run-gh-action-microvm" ]]; then
              printf '%s\n' "Run this command from the nix-gha-runner checkout." >&2
              exit 2
            fi

            exec "$PWD/run-gh-action-microvm" ${nixpkgs.lib.escapeShellArg organization} "$@"
          '';
        };
    in
    {
      lib = {
        supportedOrganizations = builtins.attrNames organizationModules;
        inherit mkRunnerConfiguration;
        mkRunner = args: (mkRunnerConfiguration args).config.microvm.declaredRunner;
      };

      packages.${system} = builtins.listToAttrs (
        map (organization: {
          name = "gh-runner-org-${organization}";
          value = mkRunnerLauncher organization;
        }) (builtins.attrNames organizationModules)
      );

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.coreutils
          pkgs.inetutils
          pkgs.openssh
          pkgs.virtiofsd
        ];
      };

      formatter.${system} = treefmtEval.config.build.wrapper;
    };
}
