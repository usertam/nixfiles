{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, ... }@inputs: {
    nixosFor = system: rec {
      # Common subset of all configurations, not meant to be used directly.
      common = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/common.nix ];
      };

      # Generic configurations that can be used out of the box or as base for custom ones.
      generic = nixpkgs.lib.recurseIntoAttrs {
        azure = common.extendModules { modules = [ ./hosts/generic-azure.nix ]; };
        docker = common.extendModules { modules = [ ./hosts/generic-docker.nix ]; };
        installer = common.extendModules { modules = [ ./hosts/generic-installer.nix ]; };
      };

      tsrvbld = common.extendModules { modules = [ ./hosts/tsrvbld.nix ]; };
      slate = common.extendModules { modules = [ ./hosts/slate.nix ]; };
      nova = common.extendModules { modules = [ ./hosts/nova.nix ]; };
    };

    darwinFor = system: {
      # This is only used for GitHub Actions to bootstrap a darwin-builder.
      runner = darwin.lib.darwinSystem {
        inherit system;
        modules = [ ./hosts/darwin-runner.nix ];
      };

      # My configuration running on MacBook Air M2.
      gale = darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/darwin-gale.nix ];
      };
    };

    packages = with nixpkgs.lib; genAttrs systems.flakeExposed (system: {
      nixosConfigurations = self.nixosFor system;
      darwinConfigurations = self.darwinFor system;
    });
  };
}
