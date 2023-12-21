{ lib, modulesPath, ... }:

{
  imports = [ "${modulesPath}/virtualisation/azure-image.nix" ];

  networking.hostName = "base";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRs9DrnxB9kZIe1ZQXAJrkaiW11dNvANWaxxquXX1x2"
  ];

  # Backport: Mount tmpfs on /tmp during boot.
  boot.tmp.useTmpfs = true;

  # Disable mounting metadata disk.
  fileSystems."/metadata".device = lib.mkForce "/dev/null";

  # TCP connections will timeout after 4 minutes on Azure.
  boot.kernel.sysctl."net.ipv4.tcp_keepalive_time" = 120;
  boot.kernel.sysctl."net.ipv4.tcp_keepalive_intvl" = 30;
  boot.kernel.sysctl."net.ipv4.tcp_keepalive_probes" = 8;

  # Disable reboot on system upgrades.
  system.autoUpgrade.allowReboot = false;
}
