{
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "encodings";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-encodings";
    rev = "06295e77b13de65842992c82f14289ea679e4730";
    hash = "sha256-JE4KSLGubCXf9hjj1pJgVOMjzySHZS6fqRJ3vJy6GSc=";
  };
}
