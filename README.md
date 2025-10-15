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
nix build .#nixosConfigurations.slate.config.system.build.toplevel
result/bin/switch-to-configuration switch
```
```sh
# After initial activation, switch with:
# nixos-rebuild switch --flake .#slate
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

### Want more speed?
Build with the binary cache! Remember `--extra-substituters` to not replace cache.nixos.org.
```sh
sudo nix build .#nixosConfigurations.generic.installer.config.system.build.toplevel \
  --extra-substituters 'https://usertam-nixfiles.cachix.org' \
  --extra-trusted-public-keys 'usertam-nixfiles.cachix.org-1:goXLh/oLkRJhgHRJcdD3/Yn7Dl6m0UZhfQxvTCZJqBI='
```

## Maintenance

### Update dependencies
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
```

## License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for more information.
