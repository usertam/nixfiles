{ lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = ''
      source ${pkgs.oh-my-zsh}/share/oh-my-zsh/lib/completion.zsh
      source ${pkgs.oh-my-zsh}/share/oh-my-zsh/lib/key-bindings.zsh
      source ${pkgs.spaceship-prompt}/share/zsh/themes/spaceship.zsh-theme
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
