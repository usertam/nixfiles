{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./common/nixos.nix
    # We didn't pick the latest kernel because ZFS support.
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Host identity.
  networking.hostName = "installer";

  services.getty.autologinUser = lib.mkForce "root";
  services.getty.helpLine = lib.mkForce (lib.trimWith { end = true; } ''

    You have reached the TTY of a fresh booted installer image.

    Any of the SSH keys below should log you in as root:
    ${pkgs.lib.concatMapStringsSep "\n" (key: "- ${key}") config.users.users.root.openssh.authorizedKeys.keys}

    Assume you want to format ZFS, do                   To create the ZFS partitions, do
        sgdisk --zap-all /dev/nvme0n1                       zfs create -o mountpoint=legacy zroot/root
        sgdisk -n 1:0:0   -t 1:BF00 \                       zfs create -o mountpoint=legacy zroot/home 
               -n 2:0:+2G -t 2:EF00 \                       zfs create -o mountpoint=legacy zroot/nix
               /dev/nvme0n1
                                                        To mount the ZFS partitions, do
        zpool create \                                      mkdir -p /mnt/home /mnt/nix
          -o ashift=12 \                                    mount -t zfs zroot/home /mnt/home
          -O atime=off \                                    mount -t zfs zroot/nix /mnt/nix
          -O compression=zstd \                             mount -t zfs zroot/root /mnt
          -O xattr=sa \
          -O acltype=posixacl \                         To create and mount the EFI system partition, do
          -O mountpoint=none \                              mkdir -p /mnt/boot
          -R /mnt \                                         mkfs.fat -F 32 -n ESP /dev/nvme0n1p2
          zroot /dev/disk/by-id/nvme-<model>-part1          mount /dev/disk/by-label/ESP /mnt/boot

    Mount your disks, run
        nixos-generate-config
        
    and finally
        nixos-install --flake github:usertam/nixfiles#<hostname>

    Door's open, bed's made.
    Welcome home.
  '');

  # Make release image.
  isoImage.compressImage = true;
  system.build.release = config.system.build.isoImage;
}
