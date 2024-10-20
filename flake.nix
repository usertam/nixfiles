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
    common = let
      sysBase = nixpkgs.lib.genAttrs systems.systems (system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./programs/common.nix
            ./programs/doas.nix
            ./programs/nix.nix
            ./programs/zsh.nix
            ./services/openssh.nix
            ./services/rsyncd.nix
            ./hosts/common.nix
          ];
        }
      );
      extendSysBase = base: base // {
        extendModules = args:
          extendSysBase (builtins.mapAttrs (_: v: v.extendModules args) base);
      };
    in extendSysBase sysBase;

    configs = with builtins; map
      (map (x: head (nixpkgs.lib.splitString "." x)) (attrNames (readDir ./hosts/configs)))
      (x: common.extendModules { modules = [ ./hosts/${x} ]; });

    # Finally, we extend the configurations with the hostname.
    nixosConfigurations = nixpkgs.lib.mapAttrs (name: config: config.extendModules {
      modules = nixpkgs.lib.singleton {
        networking.hostName = nixpkgs.lib.mkOverride 900 name;
      };
    }) self.configs;

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
