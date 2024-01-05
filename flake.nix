{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, agenix }: with self.nixosConfigurations; {
    nixosConfigurations.azure = let
      config = system: {
        name = system;
        value = nixpkgs.lib.nixosSystem {
          inherit system;
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
      listToAttrs (map config [ "x86_64-linux" "aarch64-linux" ]);

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
