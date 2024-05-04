# nixfiles

A set of opinionated `NixOS`/`nix-darwin` configurations. Home environment is managed with [usertam/nixfiles-home](https://github.com/usertam/nixfiles-home).

## Clone configuration
```sh
git clone git@github.com:usertam/nixfiles.git ~/Desktop/projects/nixfiles
cd ~/Desktop/projects/nixfiles
```

## Build and activate configuration
#### NixOS
```sh
nixos-rebuild switch --flake .#base.aarch64-linux
```
```sh
nix build .#nixosConfigurations.base.aarch64-linux.config.system.build.toplevel
result/bin/switch-to-configuration switch
```
#### nix-darwin
```sh
darwin-rebuild switch --flake .#gale
```
```sh
nix build .#darwinConfigurations.gale.config.system.build.toplevel
result/activate-user && result/activate
```

## Update flake.lock
```sh
nix flake update --commit-lock-file
```

## License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for more information.
