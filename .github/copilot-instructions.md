# Copilot Instructions

## Build, test, and run commands

- `nix flake check` is the main validation entry point for this repository.
- `nix build .#microvmConfigurations.gh-runner-org-isri-aist.config.system.build.toplevel` builds the NixOS system closure for the runner VM.
- `nix run .#gh-runner-org-isri-aist` starts the MicroVM through the flake app wrapper.
- There is no separate lint target or standalone unit-test suite in the flake today, so there is also no single-test command. For narrower validation, build or evaluate the specific flake attribute you changed.

## High-level architecture

- `flake.nix` is the entire product surface: it defines one NixOS MicroVM configuration, `microvmConfigurations.gh-runner-org-isri-aist`, and one matching app, `apps.x86_64-linux.gh-runner-org-isri-aist`, that launches it.
- The VM is assembled by combining `microvm.nixosModules.microvm`, `sops-nix.nixosModules.sops`, and a single inline module that contains all repo-specific behavior.
- Secret handling spans multiple files: `.sops.yaml` defines the age recipient policy, `secrets/secrets.yaml` stores encrypted values, and the VM mounts the host age key read-only through `virtiofs` so `sops-nix` can decrypt `isri-aist/github_token` inside the guest.
- The guest exposes one org-level GitHub Actions runner via `services.github-runners.gh-runner-org-isri-aist`. It is intentionally `ephemeral = true`, so the VM is meant for one job at a time instead of a long-lived shared runner.
- VM shutdown is coupled to runner shutdown: `ExecStopPost = poweroff` on the runner service means the guest powers itself off when the runner exits.
- The flake app does not reimplement runner wiring manually. It derives `config.microvm.declaredRunner` from the evaluated VM config, removes any stale `/tmp/sops-key.sock`, adds `virtiofsd` to `PATH`, and then execs `microvm-run`.

## Key conventions

- Keep repo-specific behavior in the inline module inside `flake.nix`. This repository does not currently split the NixOS configuration into separate module files.
- The names for the MicroVM, GitHub runner service, flake app, and SOPS secret are intentionally aligned around `gh-runner-org-isri-aist`. If one is renamed, the related attributes usually need to move together.
- Secrets follow the `sops.secrets.<name>.key` pattern, with the key pointing into nested data inside `secrets/secrets.yaml` (`isri-aist/github_token` here). Extend that mapping instead of hardcoding secret file paths.
- Host-specific paths are part of the runtime contract: the config expects the age key at `/home/arnaud/.config/sops/age/keys.txt` and the `virtiofs` socket at `/tmp/sops-key.sock`.
- The runner environment is intentionally minimal and is extended through `services.github-runners.<name>.extraPackages`. When workflows need more tooling, add packages there instead of introducing ad hoc bootstrap scripts.
- If `nixos.sock` or `nixos.sock.lock` exists in the repository root, `nix flake ...` commands can fail because Nix cannot ingest socket files as flake source input. Clean up those runtime artifacts before running flake commands.
