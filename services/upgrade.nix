{ config, lib, pkgs, ... }:

{
  system.autoUpgrade = {
    enable = lib.mkDefault true;
    operation = "boot";
    flake = ".";
    upgrade = false;
  } // lib.optionalAttrs config.nix.gc.automatic {
    runGarbageCollection = true;
  };

  systemd.services.nixos-upgrade = {
    # Set up /run/nixos-upgrade as temp directory.
    serviceConfig = {
      RuntimeDirectory = "nixos-upgrade";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "no";
      WorkingDirectory = "%t/nixos-upgrade";
    };

    # Make the new generation active after the upgrade.
    onSuccess = lib.mkIf config.systemd.services.nixos-unattended-upgrade.enable
      [ "nixos-unattended-upgrade.service" ];

    path = with pkgs; [
      curl
      diffutils
      gawk
      git
      gnupg
      jq
    ];

    # Prepend the fetching and checks to the default upgrade script.
    # Verify if latest commit is signed with the public key.
    # If unsigned, accept if it's a valid lockfile or kernel version upgrade.
    script = lib.mkBefore ''
      git clone https://github.com/usertam/nixfiles.git "$PWD"

      echo 'Trusted key for commit verification:'
      gpg --locate-keys 'code@usertam.dev' 2>&1 | sed 's/^/    /'
      echo 'EC4EE4903C8236982CABD2062D8760B0229E2560:6:' | gpg --import-ownertrust 2>&1 | sed 's/^/    /'

      echo 'Latest commit:'
      git log -1 --show-signature HEAD 2>&1 | sed 's/^/    /'
      echo

      # Skip the dependency check when the commit is properly signed.
      if git log -1 --format='%H %G? %GF' HEAD | grep -q 'G EC4EE4903C8236982CABD2062D8760B0229E2560'; then
        if ! git verify-commit HEAD &>/dev/null; then
          echo 'Could not verify signature by code@usertam.dev, abort.'
          exit 1
        fi
        echo 'Verified signature by code@usertam.dev, proceed.'
      else
        echo 'Latest commit has no signature by code@usertam.dev, comparing with last good commit.'

        # Find the last good commit that was properly signed.
        LAST_SIGNED=$(git log --format='%H %G? %GF' | \
          awk '$2 == "G" && $3 == "EC4EE4903C8236982CABD2062D8760B0229E2560" { print $1; exit }')
        if [ -z "$LAST_SIGNED" ]; then
          echo 'No commits are signed by code@usertam.dev. This should never happen, abort.'
          exit 1
        elif ! git verify-commit "$LAST_SIGNED" &>/dev/null; then
          echo "Found last signed commit ''${LAST_SIGNED:0:7} but could not verify signature, abort."
          exit 1
        fi

        # Accept only if the diff from that commit is exclusively flake.lock and kernels.json.
        CHANGED=$(git diff --name-only "$LAST_SIGNED" HEAD 2>&1)
        if grep -qvxF -e flake.lock -e hosts/common/kernels.json <<< "$CHANGED"; then
          echo 'Latest commit is unsigned but has changes beyond flake.lock and kernels.json, abort.'
          echo 'Changed files: '
          git diff --name-only "$LAST_SIGNED" HEAD 2>&1 | sed 's/^/    /'
          exit 1
        fi

        # Verify kernels.json only bumps versions. Every entry must be either
        # unchanged, or move to a strictly newer version with whatever hash.
        # Masking version and hash, the rest must be identical, so kernels
        # cannot be added, removed, or given new fields.
        if grep -qxF hosts/common/kernels.json <<< "$CHANGED"; then
          echo 'Checking kernels.json for strict version bumps...'
          if ! jq -en \
            --argjson old "$(git show "$LAST_SIGNED:hosts/common/kernels.json")" \
            --argjson new "$(git show HEAD:hosts/common/kernels.json)" '
              # Kernel.org versions as numbers, with rcs before their release: 7.3-rc5 < 7.3 < 7.3.1.
              # Anything else parses to [], which is never newer than a real version.
              def ver: [capture("^(?<maj>[0-9]+)\\.(?<min>[0-9]+)(\\.(?<pat>[0-9]+))?(-rc(?<rc>[0-9]+))?$")
                | .maj, .min, .pat // 0, .rc // infinite | tonumber];
              ($old | map_values(del(.version, .hash))) == ($new | map_values(del(.version, .hash)))
              and all($old | keys[]; $new[.] == $old[.] or ($new[.].version | ver) > ($old[.].version | ver))
            ' >/dev/null; then
            echo 'Kernel definitions have changes beyond strict version bumps, abort.'
            echo 'Change: '
            git diff "$LAST_SIGNED" HEAD -- hosts/common/kernels.json | sed 's/^/    /'
            exit 1
          fi
          echo 'Kernel definitions only have strict version bumps, proceed.'
        fi

        echo 'Latest commit only modifies flake.lock and kernels.json, proceed with lock verification.'

        # Extract the previous lockfile for comparison.
        git show "$LAST_SIGNED:flake.lock" > prev.lock

        # Verify everything except the volatile .locked node is identical.
        # The mask removes lastModified/narHash/rev from every .locked node and
        # diffs the rest, catching: input retargeting (.original node changes),
        # node membership (added/removed nodes), misc .locked metadata changes
        # (owner/repo/type drift), and transitive input graph rewires.

        echo 'Checking membership or non-volatile field changes...'
        MASK='del(.. | .locked? | .lastModified?, .narHash?, .rev?)'
        if ! diff <(jq -S "$MASK" prev.lock) <(jq -S "$MASK" flake.lock) >/dev/null; then
          echo 'Lockfile has changes outside the allowed fields (lastModified, narHash, rev), abort.'
          echo 'Change: '
          diff <(jq -S "$MASK" prev.lock) <(jq -S "$MASK" flake.lock) | sed 's/^/    /'
          exit 1
        fi
        echo 'No non-volatile changes found, proceed.'

        # Ensure pinned input invariance. Catches the case where
        # locked.rev was bumped without a matching change to original.rev.
        # Last phase misses this since locked.rev is masked away.

        echo 'Checking pinned inputs locked and original rev...'
        VIOLATED=$(jq -r '.nodes | to_entries[]
          | select(.value.original.rev)
          | select(.value.locked.rev != .value.original.rev)
          | "    - \(.key)"' flake.lock)
        if [ -n "$VIOLATED" ]; then
          echo 'Pinned inputs have mismatched locked rev, abort.'
          echo "$VIOLATED"
          exit 1
        fi
        echo 'Pinned inputs locked rev consistent, proceed.'

        echo 'Building changeset of input revs...'
        CHANGESET=$(jq -n --slurpfile a prev.lock --slurpfile b flake.lock '
          [$a[0].nodes | to_entries[]] as $old |
          [$b[0].nodes | to_entries[]] as $new |
          ($old | map({key: .key, value: .value.locked.rev}) | from_entries) as $oldrevs |
          [ $new[]
            | select($oldrevs[.key] != null)
            | select(.value.locked.rev != $oldrevs[.key])
            | {
                name: .key,
                type: .value.locked.type,
                owner: (.value.locked.owner // null),
                repo:  (.value.locked.repo // null),
                ref:   (.value.original.ref // null),
                old_rev: $oldrevs[.key],
                new_rev: .value.locked.rev
              }
          ]')

        CHANGE_COUNT=$(echo "$CHANGESET" | jq length)
        echo "Found $CHANGE_COUNT changed inputs."
        echo "$CHANGESET" | jq -r '.[] | "    + \(.name) (aka \(.type):\(.owner)/\(.repo)): \n        \(.old_rev) -> \(.new_rev)"'

        echo 'Verifying commit ancestry via GitHub API...'

        gh_api() {
          local url key val raw
          url="https://api.github.com/$1"
          key="''${2:-.}"
          raw=$(curl -s -i "$url")
          val=$(jq -r "$key" <<< "''${raw#*$'\r\n\r\n'}")
          if [ -z "$val" ] || [ "$val" = 'null' ]; then
            mkdir -p /tmp/nixos-upgrade
            echo "$raw" >> /tmp/nixos-upgrade/curl.log
            echo >&2 "    - \`curl '$url' | jq -r '$key'\` returned null, full response dumped at /tmp/nixos-upgrade/curl.log"
            echo 'null'
          else
            echo "$val"
          fi
        }

        VERIFY_FAILED=0
        for i in $(seq 0 $((CHANGE_COUNT - 1))); do
          NAME=$(echo "$CHANGESET" | jq -r ".[$i].name")
          TYPE=$(echo "$CHANGESET" | jq -r ".[$i].type")
          OWNER=$(echo "$CHANGESET" | jq -r ".[$i].owner")
          REPO=$(echo "$CHANGESET" | jq -r ".[$i].repo")
          REF=$(echo "$CHANGESET" | jq -r ".[$i].ref")
          OLD_REV=$(echo "$CHANGESET" | jq -r ".[$i].old_rev")
          NEW_REV=$(echo "$CHANGESET" | jq -r ".[$i].new_rev")

          # We can't check non-GitHub inputs right now.
          if [ "$TYPE" != "github" ]; then
            echo "    - $NAME: type '$TYPE' is not github"
            VERIFY_FAILED=1
            continue
          fi

          # Resolve default branch if ref is null.
          if [ "$REF" = "null" ]; then
            REF=$(gh_api "repos/$OWNER/$REPO" '.default_branch')
            if [ "$REF" != "null" ]; then
              echo "    + $NAME: resolved default branch to $REF"
            else
              echo "    - $NAME: failed to resolve default branch for $OWNER/$REPO"
              VERIFY_FAILED=1
              continue
            fi
          fi

          # Check A: old_rev is ancestor of new_rev.
          STATUS_A=$(gh_api "repos/$OWNER/$REPO/compare/$OLD_REV...$NEW_REV" '.status')
          if [ "$STATUS_A" = "ahead" ]; then
            echo "    + $NAME: ''${OLD_REV:0:7}...''${NEW_REV:0:7} is $STATUS_A"
          else
            echo "    - $NAME: ''${OLD_REV:0:7}...''${NEW_REV:0:7} is $STATUS_A, expected ahead"
            VERIFY_FAILED=1
            continue
          fi

          # Check B: new_rev is on the tracked branch. Staging may override
          # nixpkgs to a whitelisted branch, so accept any branch listed.
          BRANCHES=("$REF")
          case "$NAME:$REF" in
            nixpkgs:nixpkgs-unstable|nixpkgs:nixos-unstable-small)
              BRANCHES=(nixpkgs-unstable nixos-unstable-small)
              ;;
          esac

          ON_BRANCH=0
          for BRANCH in "''${BRANCHES[@]}"; do
            STATUS_B=$(gh_api "repos/$OWNER/$REPO/compare/$NEW_REV...$BRANCH" '.status')
            case "$STATUS_B" in
              ahead|identical)
                echo "    + $NAME: ''${NEW_REV:0:7}...$BRANCH is $STATUS_B"
                ON_BRANCH=1
                break
                ;;
              *)
                echo "    - $NAME: ''${NEW_REV:0:7}...$BRANCH is $STATUS_B, expected ahead or identical"
                ;;
            esac
          done
          if [ "$ON_BRANCH" -eq 0 ]; then
            VERIFY_FAILED=1
          fi
        done

        if [ "$VERIFY_FAILED" -ne 0 ]; then
          echo 'Commit ancestry checks failed, abort.'
          exit 1
        else
          echo 'Commit ancestry checks passed, proceed.'
        fi
      fi

      SYSTEM_EPOCH=$(stat -c %Y /nix/var/nix/profiles/system || awk '$1 == "btime" {print $2}' /proc/stat)
      COMMIT_SIG=$(git cat-file -p HEAD | awk '/BEGIN PGP/,/END PGP/ {sub(/^gpgsig/,""); sub(/^ /,""); print}')
      COMMIT_EPOCH=$(echo "$COMMIT_SIG" | gpg --list-packets | awk -F '[, ]+' '$3 == "created" {print $4}')

      echo 'Checking system profile and latest commit date...'
      echo "System profile date: $(date -d "@$SYSTEM_EPOCH")"
      echo "Latest commit date:  $(date -d "@$COMMIT_EPOCH")"

      if ! [ "$COMMIT_EPOCH" -gt "$SYSTEM_EPOCH" ]; then
        echo 'Current system profile is newer than commit timestamp, stop.'
        exit 0
      else
        echo 'Current system profile is older than commit timestamp, proceed.'
      fi

      echo 'Upgrade checks passed, proceeding with nixos-upgrade.'
    '';
  };

  systemd.services.nixos-unattended-upgrade = {
    description = "NixOS Unattended Upgrade";
    serviceConfig.Type = "oneshot";

    # Don't let switch-to-configuration restart this unit mid-switch.
    restartIfChanged = false;
    unitConfig.X-StopOnRemoval = false;

    # extract-vmlinux needs file to detect uncompressed images.
    path = with pkgs; [ file linux-scripts ];

    script = ''
      BOOTED_PROFILE=$(readlink -f /run/booted-system)
      ACTIVE_PROFILE=$(readlink -f /run/current-system)
      LATEST_PROFILE=$(readlink -f /nix/var/nix/profiles/system)

      # Map store paths back to generation links.
      # Take the newest if several generations share the store path.
      BOOTED_LINK=$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' \
        -lname "$BOOTED_PROFILE" -printf '%f\n' | sort -V | tail -n 1)
      ACTIVE_LINK=$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' \
        -lname "$ACTIVE_PROFILE" -printf '%f\n' | sort -V | tail -n 1)
      LATEST_LINK=$(readlink /nix/var/nix/profiles/system)

      echo "Booted system profile: $BOOTED_LINK -> $BOOTED_PROFILE"
      echo "Active system profile: $ACTIVE_LINK -> $ACTIVE_PROFILE"
      echo "Latest system profile: $LATEST_LINK -> $LATEST_PROFILE"

      if [ "$BOOTED_PROFILE" = "$LATEST_PROFILE" ]; then
        echo 'Latest system profile is booted system, nothing to do.'
        exit 0
      fi

      # Kernel version banners, as /proc/version prints them.
      # Read the latest one from its kernel image, decompressed if needed.
      BOOTED_KERNEL=$(cat /proc/version)
      LATEST_KERNEL=$(extract-vmlinux "$(readlink -f "$LATEST_PROFILE/kernel")" 2>/dev/null \
        | LC_ALL=C grep -aom1 'Linux version .*' | head -1)

      echo "Booted kernel version: $BOOTED_KERNEL"
      echo "Latest kernel version: $LATEST_KERNEL"

      if [ "$BOOTED_KERNEL" != "$LATEST_KERNEL" ] && ! ''${SKIP_REBOOT:-false}; then
        echo 'Kernel version differs from booted kernel, rebooting in 15 minutes.'
        shutdown -r +15
      elif [ "$ACTIVE_PROFILE" != "$LATEST_PROFILE" ]; then
        echo 'Switching to latest system profile.'
        "$LATEST_PROFILE/bin/switch-to-configuration" switch
      else
        echo 'Latest system profile is already active, nothing to do.'
      fi
    '';
  };
}
