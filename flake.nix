{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, ... }@inputs: {
    packages = with nixpkgs.lib; genAttrs systems.flakeExposed (system: {
      nixosConfigurations = let
        withModules = modules: nixpkgs.lib.nixosSystem {
          inherit system modules;
          specialArgs = { inherit inputs; };
        };
      in {
        generic = nixpkgs.lib.recurseIntoAttrs {
          common = withModules [ ./hosts/common/nixos.nix ];
          docker = withModules [ ./hosts/common/docker.nix ];
        };
        installer = withModules [ ./hosts/installer.nix ];
        tsrvbld = withModules [ ./hosts/tsrvbld.nix ];
        slate = withModules [ ./hosts/slate.nix ];
        nova = withModules [ ./hosts/nova.nix ];
        castor = withModules [ ./hosts/castor.nix ];
        pollux = withModules [ ./hosts/pollux.nix ];
      };

      darwinConfigurations = let
        withModules = modules: darwin.lib.darwinSystem {
          inherit system modules;
          specialArgs = { inherit inputs; };
        };
      in {
        stub = withModules [ ./hosts/stub.nix ];
        gale = withModules [ ./hosts/gale.nix ];
        work = withModules [ ./hosts/work.nix ];
      };
    });
  };
}
