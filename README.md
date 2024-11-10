# nixfiles

A set of opinionated configurations to both `NixOS` and `nix-darwin`. Home environment is managed with [usertam/nixfiles-home](https://github.com/usertam/nixfiles-home).

## Clone configuration
```sh
git clone git@github.com:usertam/nixfiles.git ~/Desktop/projects/nixfiles
cd ~/Desktop/projects/nixfiles
```

## Build and activate configuration
### NixOS
Use `nixos-rebuild`, or use `nix` to manually build and activate.
```
nixos-rebuild switch --flake .#base.aarch64-linux
```
```
nix build .#nixosConfigurations.base.aarch64-linux.config.system.build.toplevel
result/bin/switch-to-configuration switch
```
### nix-darwin
If Nix is not installed, use [DeterminateSystems/nix-installer](https://github.com/DeterminateSystems/nix-installer).
```
curl -sL https://install.determinate.systems/nix | \
  sh -s -- install macos --case-sensitive
```
Use `darwin-rebuild`, or use `nix` to run two activation scripts directly.
```
darwin-rebuild switch --flake .#gale
```
```
nix build .#darwinConfigurations.gale.config.system.build.toplevel
result/activate-user && sudo result/activate
```

## Update flake.lock
```sh
nix flake update --commit-lock-file
```

## License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for more information.
