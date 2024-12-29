# nixfiles

[![Build Image](https://github.com/usertam/nixfiles/actions/workflows/build.yml/badge.svg)](https://github.com/usertam/nixfiles/actions/workflows/build.yml)

A set of opinionated configurations to both `NixOS` and `nix-darwin`. Home environment is managed with [usertam/nixfiles-home](https://github.com/usertam/nixfiles-home).

## Clone configuration
```sh
git clone git@github.com:usertam/nixfiles.git ~/Desktop/projects/nixfiles
cd ~/Desktop/projects/nixfiles
```

## Activation

### Linux
If Nix is not installed, use [DeterminateSystems/nix-installer](https://github.com/DeterminateSystems/nix-installer).
```sh
curl -sL https://install.determinate.systems/nix | sh -s -- install
```
Build the toplevel manually with `nix`, then activate by `switch-to-configuration`.
```
nix build .#nixosConfigurations.generic.azure.config.system.build.toplevel
result/bin/switch-to-configuration switch
```
```sh
# After initial activation, switch with:
# nixos-rebuild switch --flake .#generic.azure
```
Tip: You can now build release images (.tar/iso/vhd.xz) from configurations, if supported.
```
nix build .#nixosConfigurations.generic.azure.config.system.build.release
```

### Darwin
If Nix is not installed, use [DeterminateSystems/nix-installer](https://github.com/DeterminateSystems/nix-installer). Make sure to set up a case-sensitive volume.
```sh
curl -sL https://install.determinate.systems/nix | \
  sh -s -- install macos --case-sensitive
```
Build the toplevel manually with `nix`, then run two activation scripts.
```
nix build .#darwinConfigurations.gale.config.system.build.toplevel
result/activate-user && sudo result/activate
```
```sh
# After initial activation, switch with:
# darwin-rebuild switch
```

## Maintenance
```sh
github:usertam/nixfiles
├───packages
│   ├───aarch64-linux
│   │   └───nixosConfigurations
│   │       ├───common: configuration 'nixos-system-usertam-25.05.20241227.7cc0bff'...
│   │       └───generic
│   │           ├───azure: configuration 'nixos-system-usertam-azure-25.05.20241227.7cc0bff'
│   │           │   ├───config.system.build.toplevel: derivation 'nixos-system-azure-usertam-azure-25.05.20241227.7cc0bff'
│   │           │   └───config.system.build.release: derivation 'nixos-image-usertam-azure-25.05.20241227.7cc0bff-aarch64-linux'
│   │           ├───docker: configuration 'nixos-system-usertam-docker-25.05.20241227.7cc0bff'...
│   │           └───installer: configuration 'nixos-system-usertam-installer-25.05.20241227.7cc0bff'...
│   ├───x86_64-linux────nixosConfigurations...
│   ├───riscv64-linux───nixosConfigurations...
│   ├───aarch64-darwin
│   │   └───darwinConfigurations
│   │       ├───gale: configuration 'darwin-system-25.05.20241227.7cc0bff+darwin4.bc03f78'
│   │       │   └───config.system.build.toplevel: derivation 'darwin-system-25.05.20241227.7cc0bff+darwin4.bc03f78'
│   │       └───darwin-runner: configuration 'darwin-system-25.05.20241227.7cc0bff+darwin4.bc03f78'...
│   └───x86_64-darwin───darwinConfigurations...
├───linuxPackages
│   ├───aarch64-linux...
│   ├───x86_64-linux...
│   └───riscv64-linux...
└───darwinPackages
    ├───aarch64-darwin...
    └───x86_64-darwin...
```

### Update dependencies
```sh
nix flake metadata
nix flake update --commit-lock-file

# Or, you want to pin on system's nixpkgs.
nix flake update --commit-lock-file --override-input nixpkgs nixpkgs
```

### Evaluate attributes
```
nix eval .#packages.aarch64-linux.nixosConfigurations.generic.docker.config.system.nixos.label
nix eval --apply builtins.attrNames .#darwinConfigurations.gale.config.system.build.toplevel
```

## License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for more information.
