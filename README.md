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

The secrets/secrets.yaml file is encrypted by sops using an `age` key.
To add a new token:

- For public repositories you can use a fine-grained token.
- For private repositories fine-grained tokens are not supported, you need to use a classic token.

### Fine-grained token

- Go to your github settings/developper settings/new fine grained token
- Select the desired organisation
- Click "Add Permissions" -> "Self-hosted runners"
- Select "Access: Read and write"
- Add it to secrets.yaml : `sops secrets.yaml` -> this requires `sops` to be configured to use your `age` key.
- Add the corresponding repo/org to the flake

### Classic token

Create a classic token with "admin:org" priveleges:

- Settings -> Developer settings -> Personal access tokens -> Tokens (classic) -> Generate new token -> Generate new token (classic)
- Select `admin:org` category.
