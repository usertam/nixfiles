{ config, lib, pkgs, modulesPath, ... }:

{
  # Import common modules.
  imports = [
    ../../programs/common.nix
    ../../programs/nix.nix
    ../../programs/tmux.nix
    ../../programs/zsh.nix
    ../../services/openssh.nix
    ../../services/rsyncd.nix
    ../../services/tailscale.nix
  ];

  # Auto-gen host ID based on the set hostname. Used by ZFS.
  networking.hostId =
    let
      inherit (config.networking) hostName;
      isHostNameSet = hostName != "nixos";
      hash = builtins.hashString "sha256" hostName;
      hostId = builtins.substring 0 8 hash;
    in
    lib.mkIf isHostNameSet hostId;

  # Add hostname as tag, shown in artifacts and boot.
  system.nixos.tags =
    let
      inherit (config.networking) hostName;
      isHostNameSet = hostName != "nixos";
    in
    lib.mkIf isHostNameSet [ hostName ];

  # Set time zone.
  time.timeZone = "Hongkong";

  # Define global user defaults.
  users.mutableUsers = false;

  # Link this repo read-only to /etc/nixos, assume image-based provisions.
  # Set environment.etc."nixos".enable = false for manual edits and switches.
  # Similar to system.copySystemConfiguration.
  environment.etc."nixos".source = ../..;

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

  # Assume single NIC setups.
  networking.usePredictableInterfaceNames = lib.mkDefault false;

  # Extra configurations to apply, when built as a VM.
  virtualisation.vmVariant = {
    virtualisation.diskSize = lib.mkDefault 16384; # 16 GiB
  };

  # Custom system label, re-import the original module.
  system.nixos.label =
    let
      prefix = "usertam-";
      tags = builtins.filter (tag: tag != "amazon") config.system.nixos.tags;
      version = config.system.nixos.version;
      importLabel = import "${modulesPath}/misc/label.nix" {
        inherit lib;
        config.system.nixos = { inherit tags version; };
      };
    in
      # Default module does a unconditional sort on nixos.tags, set prefix here.
      prefix + importLabel.config.system.nixos.label.content;

  # Database compatibility defaults.
  system.stateVersion = (lib.mkOverride 900) "24.05";
}
