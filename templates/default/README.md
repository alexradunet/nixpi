# Nixpi Template (Flake Init)

This directory was created with:

```bash
nix flake init -t github:alexradunet/nixpi
```

## Important: template vs full repository

`nix flake init -t ...` creates a **minimal scaffold** (mainly `flake.nix` and `nixpi-config.nix`).
It does **not** copy the full upstream repository tree (`infra/pi/skills/...`, docs, scripts, tests, etc.).

So a command like this will fail in a scaffold directory:

```bash
--skill ./infra/pi/skills/install-nixpi/SKILL.md
```

with:

- `skill path does not exist`

## First run (fresh install)

Use the helper script (recommended):

```bash
./scripts/install-nixpi-skill.sh
```

What it does:
1. Resolves the upstream Nixpi flake source path in `/nix/store`
2. Loads `install-nixpi` skill from that source
3. Starts Pi with the skill

## Manual equivalent (if needed)

```bash
NIXPI_SRC=$(nix --extra-experimental-features 'nix-command flakes' eval --impure --raw --expr '(builtins.getFlake "github:alexradunet/nixpi").outPath')

nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#nodejs_22 -c \
  npx --yes @mariozechner/pi-coding-agent@0.55.3 \
  --skill "$NIXPI_SRC/infra/pi/skills/install-nixpi/SKILL.md"
```

## Troubleshooting

### `experimental Nix feature 'nix-command' is disabled`
Use commands with:

```bash
--extra-experimental-features 'nix-command flakes'
```

### `skill path does not exist`
You are likely in a template scaffold, not a full clone. Use `./scripts/install-nixpi-skill.sh` (or the manual command above) so the skill is loaded from `/nix/store`.

### Want local `infra/pi/skills/...` paths?
Clone the full repository instead of relying only on the flake template.

## After first successful rebuild

`nixpi` is installed system-wide, and future setup/reconfiguration should use:

```bash
nixpi setup
```
