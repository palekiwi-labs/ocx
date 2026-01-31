{
  description = "ocx - a secure Docker wrapper for OpenCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, flake-utils, fenix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rustToolchain = fenix.packages.${system}.stable.toolchain;
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "ocx";
                        version = builtins.readFile ./src/VERSION.txt;

            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/bin $out/share/ocx

              # Bundle all source files and dependencies
              cp -r src $out/share/ocx/

              # Create wrapper that sets up proper environment
              makeWrapper ${pkgs.nushell}/bin/nu $out/bin/ocx \
                --add-flags "$out/share/ocx/src/main.nu"
            '';

            meta = with pkgs.lib; {
              description = "Secure Docker wrapper for OpenCode";
              homepage = "https://github.com/palekiwi-labs/ocx";
              license = licenses.mit;
              platforms = platforms.unix;
              mainProgram = "ocx";
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            rustToolchain
            pkgs.rust-analyzer
            pkgs.cargo-expand
            pkgs.cargo-watch
            pkgs.cargo-edit
          ];

          shellHook = ''
            echo "OCX Development Environment"
            echo "Rust version: $(rustc --version)"
          '';
        };
      }
    );
}
