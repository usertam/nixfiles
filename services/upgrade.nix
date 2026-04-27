{ config, lib, pkgs, ... }:

{
  system.autoUpgrade = {
    enable = true;
    flake = ".";
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
      curl
      diffutils
      gawk
      git
      gnupg
      jq
    ];

    # Overriding the default upgrade script.
    # Verify if latest commit is signed with the public key.
    # If unsigned, accept if it's a valid lockfile upgrade.
    script = lib.mkBefore (''
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

        # Accept only if the diff from that commit is exclusively flake.lock.
        CHANGED=$(git diff --name-only "$LAST_SIGNED" HEAD 2>&1)
        if [ "$CHANGED" != "flake.lock" ]; then
          echo 'Latest commit is unsigned but has changes beyond flake.lock, abort.'
          echo 'Changed files: '
          git diff --name-only "$LAST_SIGNED" HEAD 2>&1 | sed 's/^/    /'
          exit 1
        fi

        echo 'Latest commit only modifies flake.lock, proceed with lock verification.'

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
            REF=$(curl -s "https://api.github.com/repos/$OWNER/$REPO" | jq -r '.default_branch')
            echo "    + $NAME: resolved default branch to $REF"
          fi

          # Check A: old_rev is ancestor of new_rev.
          STATUS_A=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/compare/$OLD_REV...$NEW_REV" \
            | jq -r '.status')
          if [ "$STATUS_A" != "ahead" ]; then
            echo "    - $NAME: ''${OLD_REV:0:7}...''${NEW_REV:0:7} is $STATUS_A, expected ahead"
            VERIFY_FAILED=1
            continue
          else
            echo "    + $NAME: ''${OLD_REV:0:7}...''${NEW_REV:0:7} is $STATUS_A"
          fi

          # Check B: new_rev is on the tracked branch.
          STATUS_B=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/compare/$NEW_REV...$REF" \
            | jq -r '.status')
          case "$STATUS_B" in
            ahead|identical)
              echo "    + $NAME: ''${NEW_REV:0:7}...''${REF:0:7} is $STATUS_B"
              ;;
            *)
              echo "    - $NAME: ''${NEW_REV:0:7}...''${REF:0:7} is $STATUS_B, expected ahead or identical"
              VERIFY_FAILED=1
              ;;
          esac
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
    '' + lib.optionalString (config.system.autoUpgrade.operation == "switch") ''

      # Always save the built system to boot, before switch.
      ${lib.getExe pkgs.nixos-rebuild} boot ${toString config.system.autoUpgrade.flags}
    '');
  };
}
