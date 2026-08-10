{
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "sqlite_scanner";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-sqlite";
    rev = "f79b1db7d7730b18d0f8400d3650ffa6b45168d8";
    hash = "sha256-zQSB/dreOArPrrXV8KP6i/nOlSguRyOGWORvwZ5BsfI=";
  };
}
