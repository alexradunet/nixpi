# Contributing to Nixpi

Related: [AGENTS.md](./AGENTS.md) · [Source of Truth](./docs/meta/SOURCE_OF_TRUTH.md) · [Agent Skills Index](./docs/agents/SKILLS.md) · [Docs Home](./docs/README.md)

## You Don't Need NixOS to Contribute

Most of this project is plain TypeScript, shell scripts, markdown, and YAML. NixOS knowledge is only needed for the infrastructure layer.

### Contribution Tiers

| Tier | Area                         | What You Need                              | Examples                                          |
| ---- | ---------------------------- | ------------------------------------------ | ------------------------------------------------- |
| 0    | Docs, persona, skills        | Text editor + git                          | `persona/`, `infra/pi/skills/`, `docs/`           |
| 1    | TypeScript packages          | Node 22 + npm                              | `packages/nixpi-core/`, `services/matrix-bridge/` |
| 1    | Shell scripts                | bash + yq-go + jq                          | `scripts/nixpi-object.sh`                         |
| 2    | Shell tests, linting         | `nix develop` (or install yq + shellcheck) | `tests/test_*.sh`                                 |
| 3    | NixOS modules                | Nix + module system knowledge              | `infra/nixos/modules/`                            |
| 4    | Flake architecture, VM tests | NixOS + KVM                                | `flake.nix`, `tests/vm/`                          |

Pick the tier that matches your change. Everything below it is optional.

## Getting Set Up

### Without Nix (Tiers 0-1)

If you're working on TypeScript, docs, or shell scripts:

```bash
npm ci
npm -w packages/nixpi-core run build
npm -w packages/nixpi-core test
```

For shell script work, install [yq-go](https://github.com/mikefarah/yq) and [jq](https://jqlang.github.io/jq/) via your system package manager.

### With Nix (Tiers 2-4)

Install Nix via the [Determinate Nix Installer](https://install.determinate.systems/) (recommended), then:

```bash
# Option A: automatic with direnv (recommended)
# Install direnv + nix-direnv: https://nix.dev/guides/recipes/direnv.html
direnv allow

# Option B: manual
nix develop
```

Either way you get: Node 22, jq, yq-go, shellcheck, ripgrep, fd, language servers, and pre-commit hooks.

### New to Nix?

- [Zero to Nix](https://zero-to-nix.com/) — beginner tutorial (flakes-first)
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) — intermediate reference
- [nix.dev direnv guide](https://nix.dev/guides/recipes/direnv.html) — direnv setup

## Development Operating Model

- Build in **Nixpi** (repo + shell + tests).
- Use **`nixpi`** as the primary assistant interface.
- Repository files + tests + git history are the source of truth.
- If policies/docs conflict, resolve using `docs/meta/SOURCE_OF_TRUTH.md`.

## Project Layout

- **npm workspaces** (root `package.json`): `packages/nixpi-core/`, `services/matrix-bridge/`
- **Shell scripts**: `scripts/nixpi-object.sh` (requires yq-go + jq)
- **NixOS modules**: `infra/nixos/modules/` with shared factory in `infra/nixos/lib/mk-nixpi-service.nix`

## Validation

Run relevant tests for changed code, and for repo-wide checks run:

```bash
# Shell tests (require yq-go in PATH)
./scripts/test.sh
# or: nix shell nixpkgs#yq-go -c ./scripts/test.sh

# TypeScript — build and test @nixpi/core
npm -w packages/nixpi-core run build
npm -w packages/nixpi-core test

# TypeScript — build Matrix bridge
npm -w services/matrix-bridge run build

# Full checks (tests + flake validation)
./scripts/check.sh

# Optional strict check (also builds one host system closure)
NIXPI_CHECK_BUILD=1 NIXPI_CHECK_HOST=$(hostname) ./scripts/check.sh

# Optional direct flake validation
nix flake check --no-build
```

## Pre-commit Hooks

When you enter the dev shell (`nix develop` or `direnv allow`), pre-commit hooks are installed automatically. They run on `git commit` and check:

- **shellcheck** — shell script linting
- **nixfmt** — Nix file formatting (RFC 166 style)
- **prettier** — TypeScript, Markdown, YAML formatting

To run all hooks manually: `pre-commit run --all-files`

## NixOS Modules

- Each service module in `infra/nixos/modules/` has a `nixpi.<service>.enable` toggle.
- New modules should include a toggle test in `tests/vm/` that verifies the module can be enabled and disabled.
- New `.nix` files must be `git add`-ed before `nix flake check` can see them (flake check operates on git-tracked files only).

## Commit and PR Expectations

- Use clear scoped commit messages (`feat:`, `fix:`, `test:`, `docs:`, `chore:`).
- Keep PRs small and reversible.
- In PR description include:
  1. failing test(s) added first
  2. minimal code change that made them pass
  3. edge-case/regression coverage
  4. commands run + outcomes
