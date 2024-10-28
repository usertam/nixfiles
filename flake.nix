{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:usertam/nix-systems";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.systems.follows = "systems";
    agenix.inputs.darwin.follows = "darwin";
    agenix.inputs.home-manager.follows = "home-manager";
  };

  outputs = { self, nixpkgs, systems, darwin, ... }@inputs: {
    # Base configuration that includes all basic configs.
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

    # We extend the configurations specified in hosts/configs.
    nixosConfigurations = with builtins; with nixpkgs.lib; genAttrs
      (map (x: head (splitString "." x)) (attrNames (readDir ./hosts/configs)))
      (name: self.nixosCommon.extendModules {
        modules = [
          ./hosts/configs/${name}.nix
          { networking.hostName = mkOverride 900 name; }
        ];
      });

    darwinConfigurations.gale = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs; };
      modules = [
        ./programs/common.nix
        ./programs/nix.nix
        ./programs/nix-no-gc.nix
        ./programs/nix-lnxbld.nix
        ./programs/zsh.nix
        ./services/tailscale.nix
        ./hosts/darwin.nix
      ];
    };
  };
}
