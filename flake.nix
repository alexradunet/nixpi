{
  description = "nixpi: AI-centric NixOS desktop configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
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
        '';
      };

      # Desktop host configuration
      nixosConfigurations.nixpi = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./infra/nixos/desktop.nix
          ./infra/nixos/hosts/desktop.nix
        ];
      };
    };
}
