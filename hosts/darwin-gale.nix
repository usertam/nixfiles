{ ... }:

{
  # We don't have a darwin base set in flake.nix.
  # Simply import the darwin base here.
  imports = [
    ./darwin-common.nix
  ];

  environment.darwinConfig = "/Users/tam/Desktop/projects/nixfiles";

  # Prohibit self-login via SSH.
  users.sshUsers = [ ];
}
