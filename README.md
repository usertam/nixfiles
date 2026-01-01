# nixfiles

[![Build Image](https://github.com/usertam/nixfiles/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/usertam/nixfiles/actions/workflows/build.yml)

A set of opinionated configurations to both `NixOS` and `nix-darwin`. Home environment is managed with [usertam/nixfiles-home](https://github.com/usertam/nixfiles-home).

## Prerequisites: Install Nix

If Nix is not installed, run the install script at `https://artifacts.nixos.org/experimental-installer` from [NixOS/experimental-nix-installer](https://github.com/NixOS/experimental-nix-installer). It's an upstream fork of [DeterminateSystems/nix-installer](https://github.com/DeterminateSystems/nix-installer).

For Linux:
```sh
curl -sSfL https://artifacts.nixos.org/experimental-installer | sh -s -- install
```

For Darwin, to set up a case-sensitive volume:
```sh
curl -sSfL https://artifacts.nixos.org/experimental-installer | sh -s -- install macos --case-sensitive
```

## Activation

### Linux
Manually build the system toplevel derivation, then activate by `switch-to-configuration`.  
Using `nixosConfigurations.slate` as example:
```
nix build .#nixosConfigurations.slate.config.system.build.toplevel
sudo result/bin/switch-to-configuration switch
```
You may `sudo nixos-rebuild switch --flake .#slate` after initial activation.

### Darwin
Manually build the system toplevel derivation, then `sudo` the activation script.  
Using `darwinConfigurations.gale` as example:
```
nix build .#darwinConfigurations.gale.config.system.build.toplevel
sudo result/activate
```
You may `sudo darwin-rebuild switch` after initial activation.

### Want more speed?
Build with binary cache! Remember `--EXTRA-substituters` to not replace `cache.nixos.org`.
```sh
sudo nix build .#nixosConfigurations.installer.config.system.build.toplevel \
  --extra-substituters 'https://usertam-nixfiles.cachix.org' \
  --extra-trusted-public-keys 'usertam-nixfiles.cachix.org-1:goXLh/oLkRJhgHRJcdD3/Yn7Dl6m0UZhfQxvTCZJqBI='
```

## Maintenance

### Bump dependencies
```sh
nix flake metadata
nix flake update --commit-lock-file

# Or, you want to pin on system's nixpkgs.
nix flake update --commit-lock-file --override-input nixpkgs nixpkgs
```

### Build individual package
```
nix build .#darwinConfigurations.gale.config.services.tailscale.package

# Or, in nix repl.
nix-repl> :lf .
nix-repl> :b packages.aarch64-darwin.darwinConfigurations.gale.config.services.tailscale.package
```

### Evaluate attributes
```
nix eval .#packages.aarch64-linux.nixosConfigurations.generic.docker.config.system.nixos.label
nix eval --apply builtins.attrNames .#darwinConfigurations.gale.config.system.build.toplevel

# Or, if you need full-fledged nix magic:
nix eval --impure --expr '
  with builtins.getFlake (toString ./.);
  builtins.attrNames packages.aarch64-darwin.darwinConfigurations.gale.config.system.build.toplevel
'
```

## License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for more information.
