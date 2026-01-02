{ ... }:

{
  imports = [
    ./common/darwin.nix
  ];

  environment.darwinConfig = "/Users/tam/Desktop/projects/nixfiles";

  # Prohibit self-login via SSH.
  users.sshUsers = [ ];
}
