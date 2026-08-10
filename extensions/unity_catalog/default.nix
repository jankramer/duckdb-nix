{
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "unity_catalog";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "unity_catalog";
    rev = "fd851475780ca064d9706a5025ea6e5d1d9d7e23";
    hash = "sha256-Kh982A279Eb8Mgyx4CZC1XXsq8VbmOYsBxpYyYCyFjo=";
  };
}
