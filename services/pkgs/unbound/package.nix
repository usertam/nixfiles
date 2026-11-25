{ unbound-with-systemd }:

unbound-with-systemd.overrideAttrs (prev: {
  patches = prev.patches or [ ] ++ [
    # RPZ records are only ever answered from the rpz structures, yet a second
    # copy is kept in the auth zone tree. Keep just the apex there, for the
    # serial and transfer bookkeeping.
    ./0001-rpz-no-auth-copy.patch
    # Blocklists list every domain twice, as "<name>" and "*.<name>". Fold the
    # wildcard into the zone of its parent, when both have the same action.
    ./0002-rpz-fold-wildcard-twins.patch
  ];
})
