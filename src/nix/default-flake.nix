{
  description = "OCX default development environment with OpenCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    opencode.url = "github:anomalyco/opencode/v1.2.6";
  };

  outputs = { nixpkgs, flake-utils, opencode, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "ocx-default";
          buildInputs = with pkgs; [
            opencode.packages.${system}.default

            # dev utils
            ast-grep
            fd
            gh
            jq
            ripgrep
          ];
        };
      }
    );
}
