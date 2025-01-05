{ lib, pkgs, ... }:

let
  spaceship-prompt = pkgs.spaceship-prompt.overrideAttrs (prev: {
    buildInputs = with pkgs; (prev.buildInputs or []) ++ [ gnugrep gnused ];
    patches = (prev.patches or []) ++ lib.singleton (pkgs.writeText "customize-for-new-nix-shell.patch" ''
      diff --git a/sections/nix_shell.zsh b/sections/nix_shell.zsh
      index 3d35db052..77cdfccfe 100644
      --- a/sections/nix_shell.zsh
      +++ b/sections/nix_shell.zsh
      @@ -10,10 +10,11 @@
       
       SPACESHIP_NIX_SHELL_SHOW="''${SPACESHIP_NIX_SHELL_SHOW=true}"
       SPACESHIP_NIX_SHELL_ASYNC="''${SPACESHIP_NIX_SHELL_ASYNC=false}"
      +SPACESHIP_NIX_SHELL_VERSION="''${SPACESHIP_NIX_SHELL_VERSION=false}"
       SPACESHIP_NIX_SHELL_PREFIX="''${SPACESHIP_NIX_SHELL_PREFIX="$SPACESHIP_PROMPT_DEFAULT_PREFIX"}"
       SPACESHIP_NIX_SHELL_SUFFIX="''${SPACESHIP_NIX_SHELL_SUFFIX="$SPACESHIP_PROMPT_DEFAULT_SUFFIX"}"
       SPACESHIP_NIX_SHELL_SYMBOL="''${SPACESHIP_NIX_SHELL_SYMBOL="❄ "}"
      -SPACESHIP_NIX_SHELL_COLOR="''${SPACESHIP_NIX_SHELL_COLOR="yellow"}"
      +SPACESHIP_NIX_SHELL_COLOR="''${SPACESHIP_NIX_SHELL_COLOR="blue"}"
       
       # ------------------------------------------------------------------------------
       # Section
      @@ -23,12 +24,12 @@ SPACESHIP_NIX_SHELL_COLOR="''${SPACESHIP_NIX_SHELL_COLOR="yellow"}"
       spaceship_nix_shell() {
         [[ $SPACESHIP_NIX_SHELL_SHOW == false ]] && return
       
      -  [[ -z "$IN_NIX_SHELL" ]] && return
      +  [[ -z "$IN_NIX_SHELL" ]] && ! (echo "$PATH" | grep -q '/nix/store') && return
       
      -  if [[ -z "$name" || "$name" == "" ]] then
      -    display_text="$IN_NIX_SHELL"
      +  if [[ $SPACESHIP_NIX_SHELL_VERSION == true ]]; then
      +    display_text="$(echo "$PATH" | ${pkgs.gnugrep}/bin/grep -Po '/nix/store.*?/bin' | uniq | ${pkgs.gnused}/bin/sed ':a; s+/.\{42\}-++g; s+/bin++g; s/\n/, /g; N; ba;')"
         else
      -    display_text="$IN_NIX_SHELL ($name)"
      +    display_text="$(echo "$PATH" | ${pkgs.gnugrep}/bin/grep -Po '/nix/store.*?/bin' | uniq | ${pkgs.gnused}/bin/sed ':a; s+/.\{42\}-++g; s+/bin++g; s/-[0-9][0-9.]*//g; s/\n/, /g; N; ba;')"
         fi
       
         # Show prompt section
    '');
  });
in {
  programs.zsh = {
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

  # TODO: Add a programs.zsh.program option for nix-darwin.
  nixpkgs.overlays = lib.singleton (final: prev: {
    zsh = prev.runCommand prev.zsh.name {
      inherit (prev.zsh) outputs meta passthru;
      src = prev.zsh;
    } ''
      cp -a $src $out
      cp -a ${prev.zsh.doc} $doc; cp -a ${prev.zsh.info} $info; cp -a ${prev.zsh.man} $man
      chmod -R +w $out/share/zsh/5.9
      rm -rf $out/share/zsh/5.9/scripts
    '';
  });
}
