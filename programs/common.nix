{ lib, pkgs, ... }:

# The PR hasn't propagated to nixpkgs-unstable.
# https://github.com/NixOS/nixpkgs/pull/368580
let kitty = pkgs.kitty.overrideAttrs (prev: rec {
  version = "0.38.1";
  src = pkgs.fetchFromGitHub {
    owner = "kovidgoyal";
    repo = "kitty";
    rev = "refs/tags/v${version}";
    hash = "sha256-0M4Bvhh3j9vPedE/d+8zaiZdET4mXcrSNUgLllhaPJw=";
  };
  doInstallCheck = false;
  doCheck = false;
});
in
{
  environment.systemPackages = with pkgs; [
    git kitty.terminfo
  ];
}
