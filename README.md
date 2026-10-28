# nix-gha-runners - GitHub Actions runners managed by Nix

This repository contains:

- NixOS configuration for ephemeral `github-runner` MicroVMs
- SOPS secret management, requiring an `age` key to decrypt secrets
- Generic runner configuration with organization-specific modules

## Usage

- Add your `age.txt` key to `/home/arnaud/.config/sops/age/keys.txt`.
- Enter the development shell with `nix develop`, or enable it with direnv.
- Start a runner with
  `./run-gh-action-microvm [--ssh-public-key <path>] <organization> [instance-number-or-range] [loop=true]`.
- Alternatively, from this checkout, run the default instance with
  `nix run .#gh-runner-org-<organization>`.

Supported organizations are `arntanguy-sandbox` and `isri-aist`. The instance number
defaults to `1`; use a different positive number for concurrent runners of the same
organization. `run-gh-action-microvm` creates an ephemeral NixOS MicroVM that
registers a single GitHub Actions runner, completes one job, and powers itself off.
It includes the invoking host's short hostname and the instance number in the runner
name, volume paths, network interface ID, and MAC address so each host and local
instance has separate persistent resources.

Run `./run-gh-action-microvm --help` for the argument contract and lifecycle details.
Reuse an instance number to preserve that VM's Nix store and ccache overlays; choose
a different number for concurrent VMs of the same organization on one host. Use an
inclusive range such as `1-5` to start multiple instances concurrently.

The command starts every VM in the background. Per-instance output is written to
`volumes/gh-runner-org-<org>-<host>-<instance>/microvm.log`, and the corresponding
supervisor PID is stored in `microvm.pid`. The active VM PID is recorded separately
in `microvm.vm.pid`.

Gracefully drain one or more managed instances with:

```console
$ ./run-gh-action-microvm --stop isri-aist 1-5
```

`--stop` waits for the current GitHub Actions job to finish, then prevents loop mode
from starting a replacement VM. It only manages VMs started by the current launcher
and preserves their logs. To terminate immediately instead, use:

```console
$ ./run-gh-action-microvm --kill isri-aist 1-5
```

`--kill` immediately terminates the recorded VM and supervisor, then removes stale
state files.

SSH access is disabled by default. To enable it, pass a file containing one OpenSSH
public key:

```console
$ ./run-gh-action-microvm --ssh-public-key ~/.ssh/id_ed25519.pub isri-aist 1-5
```

The key authorizes `root` in the guest. The launcher prints a connection command for
each instance and forwards SSH only on `127.0.0.1`. Ports are deterministic:
`arntanguy-sandbox` uses `22000 + instance` and `isri-aist` uses
`32000 + instance`, supporting SSH-enabled instance numbers from 1 through 9999.
The printed command disables host-key checking and known-host storage because a new
guest can generate a different host key on every start. This bypass is limited to
the loopback VM endpoint; do not reuse those SSH options for remote hosts. A manually
typed plain SSH command can still report an old-key warning.

For example:

```console
$ nix develop
$ ./run-gh-action-microvm isri-aist 2
$ ./run-gh-action-microvm isri-aist 1-5
$ ./run-gh-action-microvm arntanguy-sandbox 1 true
$ ./run-gh-action-microvm --ssh-public-key ~/.ssh/id_ed25519.pub isri-aist 1
$ ./run-gh-action-microvm --stop isri-aist 1-5
$ ./run-gh-action-microvm --kill isri-aist 1-5
$ nix run .#gh-runner-org-isri-aist
$ nix run .#gh-runner-org-arntanguy-sandbox -- 1-5 true
```

The optional `loop=true` argument restarts the same VM configuration after every VM
exit, including failures. For a range, it applies to each detached supervisor
independently. Each runner remains ephemeral: after it completes a GitHub Actions
job, the guest powers itself off and the loop, when enabled, starts a new guest.

The flake outputs delegate to `run-gh-action-microvm` in the current checkout so
they retain the invoking host's hostname in runner and volume names. Run them from
the repository root; use `./run-gh-action-microvm` for an explicit path.

The flake exposes `lib.mkRunner` and `lib.mkRunnerConfiguration` for callers that
need custom settings. Both take `organization` and optional `instanceNumber`;
they also accept an optional `hostName`, which defaults to `local`.
`mkRunnerConfiguration` additionally accepts `extraModules` to override any generic
`services.nixGhaRunner` option. `run-gh-action-microvm` evaluates the local checkout with
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
