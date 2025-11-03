{ lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # TODO: use interactiveShellInit, not promptInit.
    promptInit = ''
      export HISTSIZE=1000000000
      export SAVEHIST=1000000000

      source ${pkgs.oh-my-zsh}/share/oh-my-zsh/lib/completion.zsh
      source ${pkgs.oh-my-zsh}/share/oh-my-zsh/lib/key-bindings.zsh
      setopt correct

      export LESS='-FiR'
      local CORRECT_IGNORE='[_|.]*'

      # Original programs.zsh.promptInit. Changed to off.
      autoload -U promptinit && promptinit && prompt off && setopt prompt_sp
    ''
    + builtins.concatStringsSep "\n" (
      map (x: "alias -- ${x}='${x} --color=auto'")
        [ "diff" "grep" "ls" ]
    );
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    autosuggestions.enable = true;
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # Manually install zsh-autosuggestions.
    interactiveShellInit = ''
      source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    '';
  };

  # TODO: Add a programs.zsh.program option.
  # Override the system zsh package, remove the newuser script.
  environment.systemPackages = [
    (pkgs.zsh.overrideAttrs (prev: {
      meta = prev.meta // {
        priority = -10;
      };
      postConfigure = ''
        sed -Ei '/^name=zsh\/newuser/ { s/(link=)[^ ]+/\1no/; s/(auto=)[^ ]+/\1no/ }' config.modules
      '';
    }))
  ];

  # Set default shell to zsh, in NixOS.
  users = lib.optionalAttrs pkgs.stdenv.isLinux {
    defaultUserShell = "/run/current-system/sw/bin/zsh";
  };
}
