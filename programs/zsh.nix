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

      # safer write behavior
      setopt APPEND_HISTORY            # append on exit
      setopt INC_APPEND_HISTORY_TIME   # append as you run commands, with timestamps
      setopt HIST_FCNTL_LOCK           # lock the history file to avoid races

      # kill dupes aggressively
      setopt HIST_IGNORE_DUPS          # drop if same as previous
      setopt HIST_IGNORE_ALL_DUPS      # drop older dupes on add
      setopt HIST_SAVE_NO_DUPS         # don’t write dupes to file
      setopt HIST_EXPIRE_DUPS_FIRST    # when trimming, toss dupes first
      setopt HIST_REDUCE_BLANKS        # normalize whitespace (helps dedupe)
      setopt HIST_IGNORE_SPACE         # lines starting with space aren’t saved

      export LESS='-FiR'
      local CORRECT_IGNORE='[_|.]*'

      # Original programs.zsh.promptInit. Changed to off.
      autoload -U promptinit && promptinit && prompt off && setopt prompt_sp
    ''
    + builtins.concatStringsSep "\n" (
      map (x: "alias -- ${x}='${x} --color=auto'") [
        "diff" "grep" "ls"
      ]
      ++ map (x: "alias -- t${x}='tmux new-session -A -s ${x}'") [
        "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"
      ]
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
