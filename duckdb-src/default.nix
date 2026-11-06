{ fetchFromGitHub }:

fetchFromGitHub {
  name = "duckdb-src-2.0.0";
  owner = "duckdb";
  repo = "duckdb";
  rev = "d54cbbe3df17e8e5ce68312f483b4155836112aa";
  hash = "sha256-1fhgPD/QGT/fK+BabX2dbTWOsajS6feNl5+9iw8rvwU=";
  passthru = {
    version = "2.0.0";
    gitDescribe = "v2.0.0";
    gitRevision = "d54cbbe3df17e8e5ce68312f483b4155836112aa";
  };
}
