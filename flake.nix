{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:usertam/nix-systems";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    rosetta.url = "github:usertam/rosetta";
    rosetta.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.systems.follows = "systems";
    agenix.inputs.darwin.follows = "darwin";
    agenix.inputs.home-manager.follows = "home-manager";
  };

  outputs = { self, nixpkgs, systems, darwin, ... }@inputs: let
    # Intersect the given systems and platforms.
    forLinuxSystems = with nixpkgs.lib; genAttrs (intersectLists systems.systems platforms.linux);
    forDarwinSystems = with nixpkgs.lib; genAttrs (intersectLists systems.systems platforms.darwin);
  in rec {
    linuxPackages = forLinuxSystems (system: rec {
      # The common configuration that includes all basic modules.
      nixosConfigurations.common = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./programs/common.nix
          ./programs/nix.nix
          ./programs/ssh-key.nix
          ./programs/zsh.nix
          ./services/openssh.nix
          ./services/rsyncd.nix
          ./services/tailscale.nix
          ./hosts/common.nix
        ];
      };

      # We populate nixosConfigurations.generic with <config>.<arch>.
      nixosConfigurations.generic = with nixpkgs.lib; genAttrs
        (map (x: head (splitString "." x)) (attrNames (builtins.readDir ./hosts/generic)))
        (name: nixosConfigurations.common.extendModules {
          modules = [
            ./hosts/generic/${name}.nix
            { networking.hostName = mkOverride 900 name; }
            { system.nixos.tags = mkOverride 900 [ name ]; }
          ];
        });

      nixosConfigurations.tsrvbld = nixosConfigurations.common.extendModules {
        modules = with nixpkgs.lib; [
          ./hosts/modules/intel.nix
          ./hosts/modules/boot-uefi.nix
          ./hosts/modules/boot-mnt.nix
          ./hosts/modules/gnome.nix
          ./hosts/tsrvbld.nix
          { networking.hostName = mkOverride 900 "tsrvbld"; }
          { system.nixos.tags = mkOverride 900 [ "tsrvbld" ]; }
        ];
      };
    });

    darwinPackages = forDarwinSystems (system: {
      # This is used for GitHub Actions to bootstrap a darwin-builder.
      darwinConfigurations.darwin-runner = darwin.lib.darwinSystem {
        inherit system;
        modules = nixpkgs.lib.singleton ./hosts/darwin-runner.nix;
      };

      # My configuration running on MacBook Air M2.
      darwinConfigurations.gale = darwin.lib.darwinSystem {
        inherit system;
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
    });

    packages = linuxPackages // darwinPackages;
  };
}
