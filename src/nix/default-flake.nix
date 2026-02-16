{
  description = "OCX default development environment with OpenCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    opencode.url = "github:anomalyco/opencode/dev";
  };

  outputs = { self, nixpkgs, opencode, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ opencode.overlays.default ];
          };
        in
        {
          default = pkgs.mkShell {
            name = "ocx-default";
            buildInputs = [
              pkgs.opencode
            ];
          };
        }
      );
    };
}
