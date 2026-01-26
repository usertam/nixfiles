{ ... }:

{
  imports = [
    ./common/darwin.nix
  ];

  # Host identity.
  networking.hostName = "work";

  # Set primary user.
  system.primaryUser = "samueltam";

  # Prohibit self-login via SSH.
  users.sshUsers = [ ];
}
