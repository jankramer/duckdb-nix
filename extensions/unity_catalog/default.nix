{
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "unity_catalog";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "unity_catalog";
    rev = "ad54a347dba6a1da2167c716b2c67fdfb69cd499";
    hash = "sha256-uUBnywJU3KWV2c7jSkNz9T5GhDJM5Dc3ZSf1ZpDBuhk=";
  };
}
