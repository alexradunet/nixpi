{
  description = "nixpi: AI-centric NixOS desktop configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = { self, nixpkgs, llm-agents }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ llm-agents.overlays.default ];
      };

      # Auto-discover hosts from infra/nixos/hosts/*.nix
      hostDir = ./infra/nixos/hosts;
      hostFiles = builtins.readDir hostDir;
      hostNames = map (lib.removeSuffix ".nix")
        (builtins.filter (n: lib.hasSuffix ".nix" n)
          (builtins.attrNames hostFiles));

      # Hosts that include the desktop UI layer
      desktopHosts = [ "nixpi" ];

      mkHost = name: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          { nixpkgs.overlays = [ llm-agents.overlays.default ]; }
          ./infra/nixos/base.nix
          (hostDir + "/${name}.nix")
        ] ++ lib.optionals (builtins.elem name desktopHosts) [
          ./infra/nixos/desktop.nix
        ];
      };
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

      nixosConfigurations = lib.genAttrs hostNames mkHost;
    };
}
