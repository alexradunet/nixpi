{
  description = "nixpi: reproducible dev shell + NixOS VM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-generators.url = "github:nix-community/nixos-generators";
  };

  outputs = { self, nixpkgs, flake-utils, nixos-generators }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          nodejs_22
          sqlite
          jq
          ripgrep
          fd
        ];

        shellHook = ''
          export PS1="(nixpi-dev) $PS1"
          export PATH="$PWD/node_modules/.bin:$PATH"

          if [ -f package-lock.json ] && [ ! -x node_modules/.bin/pi ]; then
            echo "[nixpi] Installing project dependencies (npm ci)..."
            npm ci --no-audit --no-fund
          fi
        '';
      };

      # Host configuration for this installed VM (safe target for nixos-rebuild switch)
      nixosConfigurations.nixpi = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./infra/nixos/vm.nix
          ./infra/nixos/hosts/nixpi.nix
        ];
      };

      packages.${system}.vm-qcow = nixos-generators.nixosGenerate {
        inherit system;
        format = "qcow";
        modules = [
          ./infra/nixos/vm.nix
        ];
      };
    };
}
