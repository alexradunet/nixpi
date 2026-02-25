# Add LSP Support for Nix, Bash, Shell, and TypeScript/JavaScript

## Context

The NixPi project has no language server support configured. The primary languages — Nix, Bash/Shell, and TypeScript/JavaScript (for the Pi wrapper) — would benefit from LSP for both AI agent development (Pi, Claude Code) and manual VS Code editing. Adding `nixd`, `bash-language-server`, `shellcheck`, and `typescript-language-server` will provide diagnostics, completions, and linting across the project.

> **Note:** Node.js (`nodejs_22`) is already installed system-wide and in the dev shell. VS Code bundles its own TS/JS language server, but `typescript-language-server` is needed for non-VS Code tooling (Pi agent, Claude Code, etc.).

## Changes

### 1. Add LSP packages to system-wide NixOS config

**File:** `infra/nixos/base.nix` (lines 236–263)

Insert a new "Language servers and linters" category after the "Development tools" block:

```nix
    # Language servers and linters
    nixd                          # Nix LSP
    bash-language-server          # Bash LSP
    shellcheck                    # Shell linter (used by bash-language-server)
    typescript-language-server    # TS/JS LSP (for Pi wrapper and non-VS Code tooling)
```

This makes them available to Pi, Claude Code, and VS Code at all times.

### 2. Add LSP packages to dev shell

**File:** `flake.nix` (lines 55–69)

Append to the `packages` list:

```nix
      # Language servers and linters
      nixd
      bash-language-server
      shellcheck
      nodePackages.typescript-language-server
```

Ensures `nix develop` provides LSP on non-NixOS machines too.

### 3. Create VS Code settings

**New file:** `.vscode/settings.json`

```json
{
  "nix.enableLanguageServer": true,
  "nix.serverPath": "nixd",
  "nix.serverSettings": {
    "nixd": {
      "nixpkgs": {
        "expr": "import <nixpkgs> {}"
      },
      "options": {
        "nixos": {
          "expr": "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.nixpi.options"
        }
      }
    }
  }
}
```

Configures the Nix IDE extension to use nixd with flake-aware NixOS option completion.

### 4. Create VS Code extension recommendations

**New file:** `.vscode/extensions.json`

```json
{
  "recommendations": [
    "jnoortheen.nix-ide",
    "timonwong.shellcheck"
  ]
}
```

Prompts VS Code users to install the relevant extensions on first open.

## Verification

1. **Dry build** — `sudo nixos-rebuild dry-build --flake .` to catch errors before applying
2. **Apply** — `sudo nixos-rebuild switch --flake .`
3. **Check binaries** — `which nixd && which bash-language-server && which shellcheck && which typescript-language-server`
4. **Dev shell** — `nix develop -c bash -c 'which nixd && which bash-language-server && which shellcheck && which typescript-language-server'`
5. **VS Code** — Open a `.nix` file, verify hover docs and completions; open a `.sh` file, verify shellcheck linting
