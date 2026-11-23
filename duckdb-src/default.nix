{ fetchFromGitHub }:

fetchFromGitHub {
  name = "duckdb-src-2.0.1";
  owner = "duckdb";
  repo = "duckdb";
  rev = "8d78114e90a53823803660bf821f6073ac87da8c";
  hash = "sha256-DJx1RsCwTIhuoSaNfqUIpDIkQ3YIOYbvGTgufBTalmk=";
  passthru = {
    version = "2.0.1";
    gitDescribe = "v2.0.1";
    gitRevision = "8d78114e90a53823803660bf821f6073ac87da8c";
  };
}
