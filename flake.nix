{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:usertam/nix-systems/linux";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "darwin";
    agenix.inputs.home-manager.follows = "home-manager";
  };

  outputs = { self, nixpkgs, systems, darwin, ... }@inputs: {
    # The common configuration that includes all basic modules.
    nixosCommon = let
      nixosBase = nixpkgs.lib.genAttrs systems.systems (system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./programs/common.nix
            ./programs/nix.nix
            ./programs/zsh.nix
            ./services/openssh.nix
            ./services/rsyncd.nix
            ./hosts/common.nix
          ];
        }
      );
      extendBase = base: base // {
        extendModules = args:
          extendBase (builtins.mapAttrs (_: v: v.extendModules args) base);
      };
    in extendBase nixosBase;

    # We populate nixosConfigurations.generic with <config>.<arch> and <arch>.
    nixosConfigurations.generic = with builtins; with nixpkgs.lib; self.nixosCommon // genAttrs
      (map (x: head (splitString "." x)) (attrNames (readDir ./hosts/generic)))
      (name: self.nixosCommon.extendModules {
        modules = [
          ./hosts/generic/${name}.nix
          { networking.hostName = mkOverride 900 name; }
        ];
      });

    darwinConfigurations.darwin-runner = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = nixpkgs.lib.singleton ./hosts/darwin-runner.nix;
    };

    darwinConfigurations.gale = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs; };
      modules = [
        ./programs/common.nix
        ./programs/nix.nix
        ./programs/nix-no-gc.nix
        ./programs/zsh.nix
        ./services/darwin-builder.nix
        ./services/tailscale.nix
        ./hosts/darwin.nix
      ];
    };
  };
}
