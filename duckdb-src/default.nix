{
  applyPatches,
  fetchFromGitHub,
}:

let
  version = "1.5.4";
  rev = "08e34c447bae34eaee3723cac61f2878b6bdf787";
  hash = "sha256-6xpKZKfH5/nwE2nU5kcpgITKFm3ilb1PYf9QEk+bKoM=";
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
