{ lib, pkgs, ... }:

# A hotfix; remove on next update.
let kitty = pkgs.kitty.overrideAttrs (prev: {
  patches = (prev.patches or []) ++ lib.singleton (pkgs.fetchpatch {
    url = "https://github.com/kovidgoyal/kitty/commit/155990ce0b3efd69acad9ec8ab97a495f5f883ed.patch";
    hash = "sha256-e2Hk/qisTEWwIrEamooIdsRKBBDwlB9t9OkDFGuokSI=";
  });
  postPatch = (prev.postPatch or "") + ''
    # Force kitty-integration no-cursor.
    substituteInPlace shell-integration/zsh/kitty-integration \
      --replace '(( ! opt[(Ie)no-cursor] ))' 'false'
  '';
  doCheck = false;
  doInstallCheck = false;
});
in
{
  environment.systemPackages = with pkgs; [
    git kitty.terminfo
  ];
}
