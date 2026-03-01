# A flake is the entry point for a Nix project — like package.json for the OS.
# It declares inputs (dependencies), outputs (packages, shells, system configs),
# and is pinned via flake.lock for reproducibility.
{
  description = "nixpi: AI-centric NixOS workstation/server configuration";

  # Pinned dependency sources. Nix fetches these and locks their exact revisions
  # in flake.lock, so every build uses identical inputs.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Track a newer Claude Code binary package while keeping the base system on 25.11.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pre-commit hooks managed by Nix — auto-installed in dev shell.
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      git-hooks,
    }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      system = "x86_64-linux";

      # Lightweight package set for VM tests. Uses stable nixpkgs with a
      # claude-code-bin stub so tests never pull the full unstable closure.
      pkgsForTests = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgsUnstableForTests = pkgsForTests // {
        claude-code-bin = pkgsForTests.writeShellScriptBin "claude" ''echo "claude-code stub for testing"'';
      };

      # Wraps testers.runNixOSTest and injects the stubbed pkgsUnstable.
      mkVmTest =
        testFile:
        pkgsForTests.testers.runNixOSTest (
          import testFile {
            inherit pkgsUnstableForTests;
          }
        );

      # Pre-commit hooks: shellcheck, nixfmt (RFC 166), prettier.
      mkPreCommitCheck =
        sys:
        git-hooks.lib.${sys}.run {
          src = ./.;
          hooks = {
            nixfmt-rfc-style.enable = true;
            shellcheck = {
              enable = true;
              args = [
                "--severity=warning"
                "--shell=bash"
                "-x"
              ];
            };
            prettier.enable = true;
          };
        };
    in
    {
      # A dev shell is a temporary environment with specific tools available.
      # `nix develop` drops you into it without installing anything globally.
      # mkShell creates a shell environment with the listed packages on $PATH.
      devShells = lib.genAttrs supportedSystems (
        sys:
        let
          pkgs = import nixpkgs { system = sys; };
          preCommit = mkPreCommitCheck sys;
        in
        {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                git
                nodejs_22
                sqlite
                jq
                yq-go # YAML processor for object frontmatter
                ripgrep
                fd

                # Language servers and linters
                nixd
                bash-language-server
                shellcheck
                nodePackages.typescript-language-server
              ]
              ++ preCommit.enabledPackages;

            shellHook = ''
              ${preCommit.shellHook}
              export PS1="(nixpi-dev) $PS1"
              export PATH="$PWD/node_modules/.bin:$PATH"
            '';
          };
        }
      );

      # NixOS modules for external consumers.
      # Use nixosModules.default for the full Nixpi stack.
      # Use individual modules for selective imports.
      nixosModules = {
        default = ./infra/nixos/base.nix;
        base = ./infra/nixos/base.nix;
        tailscale = ./infra/nixos/modules/tailscale.nix;
        syncthing = ./infra/nixos/modules/syncthing.nix;
        ttyd = ./infra/nixos/modules/ttyd.nix;
        matrix = ./infra/nixos/modules/matrix.nix;
        heartbeat = ./infra/nixos/modules/heartbeat.nix;
        objects = ./infra/nixos/modules/objects.nix;
        passwordPolicy = ./infra/nixos/modules/password-policy.nix;
        desktop = ./infra/nixos/modules/desktop.nix;
      };

      # Flake template for new Nixpi installations.
      # Usage: nix flake init -t github:alexradunet/nixpi
      templates.default = {
        path = ./templates/default;
        description = "Nixpi server configuration scaffold";
      };

      # NixOS VM integration tests. Each test boots a QEMU VM and asserts
      # runtime behavior (services, firewall, users, activation scripts).
      # Run one:  nix build .#checks.x86_64-linux.vm-user-and-groups --no-link -L
      # Run all:  nix flake check -L
      checks =
        lib.genAttrs supportedSystems (sys: {
          pre-commit-check = mkPreCommitCheck sys;
        })
        // {
          x86_64-linux = {
            pre-commit-check = mkPreCommitCheck "x86_64-linux";
            vm-assistant-user = mkVmTest ./tests/vm/assistant-user.nix;
            vm-user-and-groups = mkVmTest ./tests/vm/user-and-groups.nix;
            vm-ssh-hardening = mkVmTest ./tests/vm/ssh-hardening.nix;
            vm-firewall-rules = mkVmTest ./tests/vm/firewall-rules.nix;
            vm-activation-scripts = mkVmTest ./tests/vm/activation-scripts.nix;
            vm-service-ensemble = mkVmTest ./tests/vm/service-ensemble.nix;
            vm-password-policy = mkVmTest ./tests/vm/password-policy.nix;
            vm-objects-data-dir = mkVmTest ./tests/vm/objects-data-dir.nix;
            vm-persona-injection = mkVmTest ./tests/vm/persona-injection.nix;
            vm-heartbeat-timer = mkVmTest ./tests/vm/heartbeat-timer.nix;
            vm-matrix-bridge = mkVmTest ./tests/vm/matrix-bridge.nix;
            vm-matrix-bridge-errors = mkVmTest ./tests/vm/matrix-bridge-errors.nix;
            vm-matrix-bridge-queue = mkVmTest ./tests/vm/matrix-bridge-queue.nix;
            vm-tailscale-toggle = mkVmTest ./tests/vm/tailscale-toggle.nix;
            vm-ttyd-toggle = mkVmTest ./tests/vm/ttyd-toggle.nix;
            vm-syncthing-toggle = mkVmTest ./tests/vm/syncthing-toggle.nix;
            vm-password-policy-toggle = mkVmTest ./tests/vm/password-policy-toggle.nix;
            vm-desktop-toggle = mkVmTest ./tests/vm/desktop-toggle.nix;
            vm-minimal-config = mkVmTest ./tests/vm/minimal-config.nix;
            vm-full-stack = mkVmTest ./tests/vm/full-stack.nix;
            vm-secrets-directory = mkVmTest ./tests/vm/secrets-directory.nix;
            vm-service-hardening = mkVmTest ./tests/vm/service-hardening.nix;
            vm-heartbeat-oncalendar = mkVmTest ./tests/vm/heartbeat-oncalendar.nix;
            vm-objects-custom-types = mkVmTest ./tests/vm/objects-custom-types.nix;
            vm-password-policy-boundary = mkVmTest ./tests/vm/password-policy-boundary.nix;
            vm-grub-disabled-by-default = mkVmTest ./tests/vm/grub-disabled-by-default.nix;
          };
        };
    };
}
