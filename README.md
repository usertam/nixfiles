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
Build the system toplevel derivation, then activate by `switch-to-configuration`:
```sh
nix build github:usertam/nixfiles#nixosConfigurations.slate.config.system.build.toplevel
sudo result/bin/switch-to-configuration switch
```

After initial activation, you may run:
```
sudo nixos-rebuild switch --flake github:usertam/nixfiles#slate
```

### Darwin
Build the system toplevel derivation, then run the activation script:
```sh
nix build github:usertam/nixfiles#darwinConfigurations.gale.config.system.build.toplevel
sudo result/activate
```

After initial activation, you may run:
```
sudo darwin-rebuild switch --flake github:usertam/nixfiles#gale
```

### Using binary cache
You will need to be root or `trusted-users` to specify new binary cache.

For Linux using nixos-rebuild:
```sh
sudo nixos-rebuild switch \
  --flake github:usertam/nixfiles#slate \
  --option extra-substituters 'https://cache.usertam.dev' \
  --option extra-trusted-public-keys 'cache.usertam.dev-1:slGg+FqFFc/qeCXyfoxBv+uuGDsUAyEbNkgwEEfw4uE='
```

For Darwin using darwin-rebuild:
```sh
sudo darwin-rebuild switch \
  --flake github:usertam/nixfiles#gale \
  --option extra-substituters 'https://cache.usertam.dev' \
  --option extra-trusted-public-keys 'cache.usertam.dev-1:slGg+FqFFc/qeCXyfoxBv+uuGDsUAyEbNkgwEEfw4uE='
```

Use Nix to build the system toplevel only:
```sh
# at cloned repository
sudo nix build .#nixosConfigurations.installer.config.system.build.toplevel \
  --extra-substituters 'https://cache.usertam.dev' \
  --extra-trusted-public-keys 'cache.usertam.dev-1:slGg+FqFFc/qeCXyfoxBv+uuGDsUAyEbNkgwEEfw4uE='
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
