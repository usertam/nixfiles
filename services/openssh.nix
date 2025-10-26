{ config, lib, pkgs, ... }:

{
  # Abstract over setting authorized keys per user. We reuse the same key anyway.
  # Warning: this will allow self-login as root if a regular user stores the key on the same system.
  options.users.sshUsers = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ "root" ];
    description = "Users to add the default SSH key to.";
  };

  config = {
    services.openssh = {
      enable = true;
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
      '';
    };

    users.users = lib.mkIf (config.users.sshUsers != [ ]) (
      builtins.foldl' (
        attr: user:
        attr
        // {
          "${user}".openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
          ];
        }
      ) { } config.users.sshUsers
    );
  };
}
