{ ... }:

let
  dir = builtins.readDir ./.;
  secrets = with builtins; filter
    (x: match ".*\.nix" x == null && dir.${x} == "regular")
    (attrNames dir);
in {
  age.secrets = with builtins; foldl' (x: y: x // y) {}
    (map (name: { ${name}.file = ./${name}; }) secrets);
}
