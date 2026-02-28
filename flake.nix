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
  };

  outputs = { self, nixpkgs, nixpkgs-unstable }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      system = "x86_64-linux"; # Default for nixosConfigurations; hosts override via nixpkgs.hostPlatform
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # Lightweight package set for VM tests. Uses stable nixpkgs with a
      # claude-code-bin stub so tests never pull the full unstable closure.
      pkgsForTests = import nixpkgs { inherit system; config.allowUnfree = true; };
      pkgsUnstableForTests = pkgsForTests // {
        claude-code-bin = pkgsForTests.writeShellScriptBin "claude" ''echo "claude-code stub for testing"'';
      };

      # Wraps testers.runNixOSTest and injects the stubbed pkgsUnstable.
      mkVmTest = testFile: pkgsForTests.testers.runNixOSTest (import testFile {
        inherit pkgsUnstableForTests;
      });

      # Auto-discover hosts: every .nix file in hosts/ becomes a NixOS config.
      # Adding a new file (e.g. hosts/mybox.nix) automatically registers it —
      # no need to touch flake.nix.
      hostDir = ./infra/nixos/hosts;
      hostFiles = builtins.readDir hostDir;
      hostNames = map (lib.removeSuffix ".nix")
        (builtins.filter (n: lib.hasSuffix ".nix" n)
          (builtins.attrNames hostFiles));

      # mkHost builds a full NixOS system for a given hostname.
      # nixosSystem takes a list of "modules" — each module is a file that
      # declares part of the system config. NixOS deep-merges them all together.
      mkHost = name: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit pkgsUnstable;
        };
        modules = [
          ./infra/nixos/base.nix
          (hostDir + "/${name}.nix")
        ];
      };
    in {
      # A dev shell is a temporary environment with specific tools available.
      # `nix develop` drops you into it without installing anything globally.
      # mkShell creates a shell environment with the listed packages on $PATH.
      devShells = lib.genAttrs supportedSystems (sys:
        let pkgs = import nixpkgs { system = sys; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              git
              nodejs_22
              sqlite
              jq
              yq-go        # YAML processor for object frontmatter
              ripgrep
              fd

              # Language servers and linters
              nixd
              bash-language-server
              shellcheck
              nodePackages.typescript-language-server
            ];

            shellHook = ''
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

      # genAttrs turns a list of names into an attribute set by applying a
      # function to each name. This produces { nixpi = mkHost "nixpi"; ... }
      # for every host discovered above.
      nixosConfigurations = lib.genAttrs hostNames mkHost;

      # NixOS VM integration tests. Each test boots a QEMU VM and asserts
      # runtime behavior (services, firewall, users, activation scripts).
      # Run one:  nix build .#checks.x86_64-linux.vm-user-and-groups --no-link -L
      # Run all:  nix flake check -L
      checks.x86_64-linux = {
        vm-assistant-user     = mkVmTest ./tests/vm/assistant-user.nix;
        vm-user-and-groups    = mkVmTest ./tests/vm/user-and-groups.nix;
        vm-ssh-hardening      = mkVmTest ./tests/vm/ssh-hardening.nix;
        vm-firewall-rules     = mkVmTest ./tests/vm/firewall-rules.nix;
        vm-activation-scripts = mkVmTest ./tests/vm/activation-scripts.nix;
        vm-service-ensemble   = mkVmTest ./tests/vm/service-ensemble.nix;
        vm-password-policy    = mkVmTest ./tests/vm/password-policy.nix;
        vm-objects-data-dir   = mkVmTest ./tests/vm/objects-data-dir.nix;
        vm-persona-injection  = mkVmTest ./tests/vm/persona-injection.nix;
        vm-heartbeat-timer    = mkVmTest ./tests/vm/heartbeat-timer.nix;
        vm-matrix-bridge      = mkVmTest ./tests/vm/matrix-bridge.nix;
        vm-tailscale-toggle   = mkVmTest ./tests/vm/tailscale-toggle.nix;
        vm-ttyd-toggle        = mkVmTest ./tests/vm/ttyd-toggle.nix;
        vm-syncthing-toggle   = mkVmTest ./tests/vm/syncthing-toggle.nix;
        vm-password-policy-toggle = mkVmTest ./tests/vm/password-policy-toggle.nix;
        vm-desktop-toggle     = mkVmTest ./tests/vm/desktop-toggle.nix;
        vm-minimal-config     = mkVmTest ./tests/vm/minimal-config.nix;
        vm-full-stack         = mkVmTest ./tests/vm/full-stack.nix;
        vm-secrets-directory  = mkVmTest ./tests/vm/secrets-directory.nix;
        vm-service-hardening  = mkVmTest ./tests/vm/service-hardening.nix;
        vm-heartbeat-oncalendar = mkVmTest ./tests/vm/heartbeat-oncalendar.nix;
        vm-objects-custom-types = mkVmTest ./tests/vm/objects-custom-types.nix;
        vm-password-policy-boundary = mkVmTest ./tests/vm/password-policy-boundary.nix;
      };
    };
}
