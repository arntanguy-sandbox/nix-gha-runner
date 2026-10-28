# nix-gha-runners - GitHub Actions runners managed by Nix

This repository contains:

- NixOS configuration for ephemeral `github-runner` MicroVMs
- SOPS secret management, requiring an `age` key to decrypt secrets
- Generic runner configuration with organization-specific modules

## Usage

- Add your `age.txt` key to `/home/arnaud/.config/sops/age/keys.txt`.
- Enter the development shell with `nix develop`, or enable it with direnv.
- Start a runner with `./run-host <organization> [instance-number] [loop=true]`.

Supported organizations are `arntanguy-sandbox` and `isri-aist`. The instance number
defaults to `1`; use a different positive number for concurrent runners of the same
organization. `run-host` includes the invoking host's short hostname and the instance
number in the runner name, volume paths, network interface ID, and MAC address so
each host and local instance has separate persistent resources.

For example:

```console
$ nix develop
$ ./run-host isri-aist 2
$ ./run-host arntanguy-sandbox 1 true
```

The optional `loop=true` argument restarts the same VM configuration after every VM
exit, including failures. Without it, `run-host` exits with the VM's exit status.
Each runner remains ephemeral: after it completes a GitHub Actions job, the guest
powers itself off and the loop, when enabled, starts a new guest.

The flake exposes `lib.mkRunner` and `lib.mkRunnerConfiguration` for callers that
need custom settings. Both take `organization` and optional `instanceNumber`;
they also accept an optional `hostName`, which defaults to `local`.
`mkRunnerConfiguration` additionally accepts `extraModules` to override any generic
`services.nixGhaRunner` option. `run-host` evaluates the local checkout with
`--impure` because this Nix version cannot apply arguments to a function-valued flake
output; the runner configuration itself has no environment-dependent settings.

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
