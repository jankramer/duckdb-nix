{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      mkPkgs = system: { pkgs = import nixpkgs { inherit system; }; };
      mkOutput = func: nixpkgs.lib.genAttrs systems (system: func (mkPkgs system));
    in
    {
      overlays.default = final: prev: { duckdb = final.callPackage ./default.nix { }; };

      packages = mkOutput (
        { pkgs }:
        {
          default = pkgs.callPackage ./default.nix { };
        }
      );
    };
}
