{ config, lib, pkgs, modulesPath, ... }:

{
  # Import common modules.
  imports = [
    ../programs/common.nix
    ../programs/nix.nix
    ../programs/tmux.nix
    ../programs/zsh.nix
    ../services/openssh.nix
    ../services/rsyncd.nix
    ../services/tailscale.nix
  ];

  # Set time zone.
  time.timeZone = "Hongkong";

  # Define global user defaults.
  users.mutableUsers = false;

  # Link this repo read-only to /etc/nixos, assume image-based provisions.
  # Set environment.etc."nixos".enable = false for manual edits and switches.
  # Similar to system.copySystemConfiguration.
  environment.etc."nixos".source = ./..;

  # Raise soft file descriptors limit from 1024 to 65536. Hard limit remains same.
  # Mostly for user; not too worried about services, as systemd sets it to hard limit already.
  # You can check /proc/<pid>/limits to be sure.
  systemd.settings.Manager.DefaultLimitNOFILE = "65536:524288";
  systemd.user.extraConfig = "DefaultLimitNOFILE=65536:524288";
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "65536"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "524288"; }
  ];

  # Set default login user root.
  services.getty.autologinUser = lib.mkDefault "root";

  # Hacky way to prepend to the default `system.nixos.tags`.
  system.nixos.label = "usertam-"
    + (import "${modulesPath}/misc/label.nix" { inherit config lib; }).config.system.nixos.label.content;

  # Database compatibility defaults.
  system.stateVersion = (lib.mkOverride 900) "24.05";
}
