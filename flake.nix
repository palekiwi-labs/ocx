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

        # Create Rust platform for building
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        # Common Rust package arguments
        rustPackageBase = {
          src = ./rust;
          cargoLock.lockFile = ./rust/Cargo.lock;

          # Build in release mode
          buildType = "release";

          # Metadata
          meta = with pkgs.lib; {
            license = licenses.mit;
            platforms = platforms.unix;
          };
        };

        # Build client binary (for container)
        host-exec-client = rustPlatform.buildRustPackage (rustPackageBase // {
          pname = "host-exec";
          version = "0.1.0";

          # Build only the client crate
          cargoBuildFlags = [ "-p" "host-exec" ];
          cargoTestFlags = [ "-p" "host-exec" ];

          meta = rustPackageBase.meta // {
            description = "host-exec client for container";
            mainProgram = "host-exec";
          };
        });

        # Build server binary (for host)
        host-exec-server = rustPlatform.buildRustPackage (rustPackageBase // {
          pname = "host-exec-server";
          version = "0.1.0";

          # Build only the server crate
          cargoBuildFlags = [ "-p" "host-exec-server" ];
          cargoTestFlags = [ "-p" "host-exec-server" ];

          meta = rustPackageBase.meta // {
            description = "host-exec server for host machine";
            mainProgram = "host-exec-server";
          };
        });

      in
      {
        packages = {
          # Expose individual Rust binaries
          inherit host-exec-client host-exec-server;

          # Main ocx package (updated)
          default = pkgs.stdenv.mkDerivation {
            pname = "ocx";
            version = builtins.readFile ./src/VERSION.txt;

            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/bin $out/share/ocx $out/libexec $out/share/ocx/binaries

              # Bundle all Nushell source files
              cp -r src $out/share/ocx/

              # Install server binary to libexec (for host use)
              cp ${host-exec-server}/bin/host-exec-server $out/libexec/

              # Install client binary to shared location (for Docker build context)
              cp ${host-exec-client}/bin/host-exec $out/share/ocx/binaries/

              # Create wrapper with access to binaries
              makeWrapper ${pkgs.nushell}/bin/nu $out/bin/ocx \
                --add-flags "$out/share/ocx/src/main.nu" \
                --set OCX_SERVER_BIN "$out/libexec/host-exec-server" \
                --set OCX_CLIENT_BIN "$out/share/ocx/binaries/host-exec"
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
