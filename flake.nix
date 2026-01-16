{
  description = "ocx - a secure Docker wrapper for OpenCode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "ocx";
            version = "0.1.0";
            
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
              homepage = "https://github.com/palekiwi/ocx";
              license = licenses.mit;
              platforms = platforms.unix;
              mainProgram = "ocx";
            };
          };
        };
      }
    );
}
