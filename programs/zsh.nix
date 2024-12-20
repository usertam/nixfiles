{ lib, pkgs, ... }:

{
  programs.zsh = let
    spaceship-prompt = pkgs.spaceship-prompt.overrideAttrs (prev: {
      patches = (prev.patches or []) ++ lib.singleton (pkgs.fetchpatch {
        name = "customize-for-new-nix-shell.patch";
        url = "https://github.com/usertam/spaceship-prompt/commit/5b82eb25ad87a6c0b62c0681794bd0332b285f7e.patch";
        hash = "sha256-eZYw2J652iZZYvTMAAJqnTYb7PO4xuCcR4LTHLB3FeM=";
      });
    });
  in {
    enable = true;
    enableCompletion = true;
    promptInit = ''
      source ${pkgs.oh-my-zsh}/share/oh-my-zsh/lib/completion.zsh
      source ${pkgs.oh-my-zsh}/share/oh-my-zsh/lib/key-bindings.zsh
      source ${spaceship-prompt}/share/zsh/themes/spaceship.zsh-theme
      setopt correct
    '' + ''
      export LESS='-R'
      local SPACESHIP_EXEC_TIME_PRECISION=0
      local CORRECT_IGNORE='[_|.]*'
    '' + builtins.concatStringsSep "\n" (map
      (x: "alias ${x}='${x} --color=auto'")
      [ "diff" "grep" "ls" ]
    );
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    autosuggestions.enable = true;
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # Manually install zsh-autosuggestions.
    interactiveShellInit = lib.mkIf pkgs.stdenv.isDarwin ''
      source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    '';
  };
}
