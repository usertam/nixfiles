{ lib, ... }:

{
  # Replace sudo with doas.
  security.sudo.enable = lib.mkDefault false;
  security.doas = {
    enable = true;
    wheelNeedsPassword = false;
  };
  environment.shellAliases.sudo = "doas";
}
