# nix-gha-runners - Github action runners managed by Nix

This repository contains:

- Nixos configuration for `github-runner`
- Sops secret management, requires an `age` key to decrypt the secrets
- MicroVM configuration using the `github-runner` nixos configurations
- A Nix flake to run the MicroVM

## Usage

- Add your `age.txt` key to `/home/arnaud/.config/sops/age/keys.txt`.
- `nix run .#gh-runner-org-arntanguy-sandbox` or any supported org/repo name.

## Personnal access tokens

The secrets/secrets.yaml file is encrypted by sops using an `age` key. To add a new token:

- Go to your github settings/developper settings/new fine grained token
- Select the desired organisation
- Give it "Read and Write access to organization/repository self hosted runners", depending on whether it is organization wide or per-repository.
- Add it to secrets.yaml : `sops secrets.yaml` -> this requires `sops` to be configured to use your `age` key.
- Add the corresponding repo/org to the flake
