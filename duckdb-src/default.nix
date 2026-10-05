{
  applyPatches,
  fetchFromGitHub,
}:

let
  version = "1.5.6";
  rev = "069cc9f9b5be802405797faecc284961b07c70ef";
  hash = "sha256-xHcucJA+2nTD9oeoZxDQzGS6QNnzjHQ7t9sz0OHA+zo=";
in

applyPatches {
  src = fetchFromGitHub {
    name = "duckdb-src-${version}";
    owner = "duckdb";
    repo = "duckdb";

    inherit rev hash;

    passthru = {
      inherit version;
      gitDescribe = "v${version}-0-g${builtins.substring 0 10 rev}";
    };
  };

  patches = map (p: ./. + ("/patches/" + p)) (builtins.attrNames (builtins.readDir ./patches));
}
