{ config, lib, ... }:

{
  # Abstract over setting authorized keys. We reuse the same key anyway.
  options.users.sshUsers = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ "root" ];
    description = "Users to add the default SSH key to.";
  };

  config = {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  } // lib.mkIf (config.users.sshUsers != []) {
    users.users = builtins.foldl' (attr: user: attr // {
      "${user}".openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
      ];
    }) {} config.users.sshUsers;
  };
}
