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
      rev = "274a3307341dcafd62471c09b45c5d858d6c95cc";
      hash = "sha256-I3LtOipBN+WuYiuWvt9sptc7mVglutxo/lMQCvsoz8o=";
    };

    patches = [ ./no-git-version.patch ];
  };

  buildInputs = [ unixodbc ];
}
