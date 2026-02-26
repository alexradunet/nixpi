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
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

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
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          nodejs_22
          sqlite
          jq
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

      # genAttrs turns a list of names into an attribute set by applying a
      # function to each name. This produces { nixpi = mkHost "nixpi"; ... }
      # for every host discovered above.
      nixosConfigurations = lib.genAttrs hostNames mkHost;
    };
}
