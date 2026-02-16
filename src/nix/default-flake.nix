{
  description = "OCX default development environment with OpenCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    opencode.url = "github:anomalyco/opencode/dev";
  };

  outputs = { nixpkgs, flake-utils, opencode, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ opencode.overlays.default ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "ocx-default";
          buildInputs = [
            pkgs.opencode
          ];
        };
      }
    );
}
