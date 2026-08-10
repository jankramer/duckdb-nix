{
  applyPatches,
  fetchFromGitHub,
}:

let
  version = "1.5.5";
  rev = "d8cdaa33fda8df955cc76ef58a280f68f4cd43fa";
  hash = "sha256-vFXrMcWF5KDYYRjWZb6iJdhGnCAb6SMlSgzlcr+FQ8Y=";
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
