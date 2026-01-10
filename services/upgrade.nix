{ config, lib, pkgs, ... }:

{
  system.autoUpgrade = {
    enable = true;
    flake = "./flake";
    upgrade = false;
  } // lib.optionalAttrs (config.swapDevices != [ ]) {
    runGarbageCollection = true;
    flags = [
      "--option"
      "extra-substituters"
      "https://usertam-nixfiles.cachix.org"
    ];
  };

  systemd.services.nixos-upgrade = {
    # Set up /run/nixos-upgrade as temp directory.
    serviceConfig = {
      RuntimeDirectory = "nixos-upgrade";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "no";
      WorkingDirectory = "%t/nixos-upgrade";
    };

    path = with pkgs; [
      git
      gnupg
      gawk
    ];

    # Verify if latest commit is signed, hardcode key signature for now.
    script = lib.mkBefore ''
      echo "Cloning nixfiles to '$PWD/flake'..."
      git clone https://github.com/usertam/nixfiles.git ./flake

      echo 'Trusted key for commit verification:'
      gpg --locate-keys 'code@usertam.dev' 2>&1 | sed 's/^/    /'
      echo 'EC4EE4903C8236982CABD2062D8760B0229E2560:6:' | gpg --import-ownertrust 2>&1 | sed 's/^/    /'

      echo 'Latest commit:'
      git -C ./flake log -1 --show-signature HEAD 2>&1 | sed 's/^/    /'

      if ! git -C ./flake log -1 --format='%H %G? %GF' HEAD | grep -q 'G EC4EE4903C8236982CABD2062D8760B0229E2560'; then
        echo 'Commit is not signed by code@usertam.dev, abort.'
        exit 1
      fi

      if ! git -C ./flake verify-commit HEAD &>/dev/null; then
        echo 'Commit signature could not be verified by gpg, abort.'
        exit 1
      fi

      SYSTEM_EPOCH=$(stat -c %Y /nix/var/nix/profiles/system || awk '$1 == "btime" {print $2}' /proc/stat)
      COMMIT_SIG=$(git -C ./flake cat-file -p HEAD | awk '/BEGIN PGP/,/END PGP/ {sub(/^gpgsig/,""); sub(/^ /,""); print}')
      COMMIT_EPOCH=$(echo "$COMMIT_SIG" | gpg --list-packets | awk -F '[, ]+' '$3 == "created" {print $4}')

      echo "System profile date: $(date -d "@$SYSTEM_EPOCH")"
      echo "Latest commit date:  $(date -d "@$COMMIT_EPOCH")"

      if ! [ "$COMMIT_EPOCH" -gt "$SYSTEM_EPOCH" ]; then
        echo 'Commit signature is older than (or same as) current system profile, abort.'
        exit 1
      fi

      echo 'Upgrade checks passed, proceeding with nixos-upgrade.'
    '';
  };
}
