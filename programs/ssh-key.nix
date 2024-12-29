{ config, lib, ... }:

{
  # Define the default SSH key for users. Do not use "root" in personal systems.
  options.users.defaultKeyUsers = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ "root" ];
    description = "Users to add the default SSH key to.";
  };

  config = lib.mkIf (config.users.defaultKeyUsers != []) {
    users.users = builtins.foldl' (attr: user: attr // {
      "${user}".openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
      ];
    }) {} config.users.defaultKeyUsers;
  };
}
