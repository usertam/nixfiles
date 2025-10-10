{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, ... }@inputs: rec {
    linuxPackages = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.linux (system: rec {
      # Common subset of all configurations, not meant to be used directly.
      nixosConfigurations.common = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/common.nix ];
      };

      # Generic configurations that can be used out of the box or as base for custom ones.
      nixosConfigurations.generic = nixpkgs.lib.recurseIntoAttrs {
        azure = nixosConfigurations.common.extendModules {
          modules = [ ./hosts/generic-azure.nix ];
        };
        docker = nixosConfigurations.common.extendModules {
          modules = [ ./hosts/generic-docker.nix ];
        };
        installer = nixosConfigurations.common.extendModules {
          modules = [ ./hosts/generic-installer.nix ];
        };
      };

      nixosConfigurations.tsrvbld = nixosConfigurations.common.extendModules {
        modules = [ ./hosts/tsrvbld.nix ];
      };

      nixosConfigurations.slate = nixosConfigurations.common.extendModules {
        modules = [ ./hosts/slate.nix ];
      };
    });

    darwinPackages = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.darwin (system: {
      # This is used for GitHub Actions to bootstrap a darwin-builder.
      darwinConfigurations.darwin-runner = darwin.lib.darwinSystem {
        inherit system;
        modules = [ ./hosts/darwin-runner.nix ];
      };

      # My configuration running on MacBook Air M2.
      darwinConfigurations.gale = darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/darwin.nix ];
      };
    });

    packages = linuxPackages // darwinPackages;
  };
}
