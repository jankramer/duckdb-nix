{
  applyPatches,
  fetchFromGitHub,
  mkExtension,
  unixodbc,
}:

mkExtension {
  name = "odbc_scanner";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "odbc-scanner";
      rev = "8a3266017af8a9abf14a49e2fd5df83d64eb5520";
      hash = "sha256-4P4Atpb2AkNAqUNxddjVvlp6PSEwORTJE/4jW/YeEuE=";
    };

    patches = [ ./no-git-version.patch ];
  };

  buildInputs = [ unixodbc ];
}
