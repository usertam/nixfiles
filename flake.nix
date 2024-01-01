{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, agenix }: let
    specialArgs.lock = nixpkgs.lib.importJSON ./flake.lock;
    systems = [ "x86_64-linux" "aarch64-linux" ];
  in with self.nixosConfigurations; {
    nixosConfigurations.azure = let
      config = system: {
        name = system;
        value = nixpkgs.lib.nixosSystem {
          inherit specialArgs system;
          modules = [
            ./programs/common.nix
            ./programs/doas.nix
            ./programs/nix.nix
            ./programs/zsh.nix
            ./services/openssh.nix
            ./services/rsyncd.nix
            ./hosts/common.nix
            ./hosts/azure-base.nix
          ];
        };
      };
    in with builtins;
      listToAttrs (map config systems);

    nixosConfigurations.srv01 = azure.x86_64-linux.extendModules {
      modules = [
        { networking.hostName = "srv01"; }
        agenix.nixosModules.default
        ./secrets/catalog.nix
      ];
    };

    nixosConfigurations.srv02 = azure.x86_64-linux.extendModules {
      modules = [
        { networking.hostName = "srv02"; }
        agenix.nixosModules.default
        ./secrets/catalog.nix
        ./services/v2ray.nix
      ];
    };
  };
}
