{ pkgs ? import <nixpkgs> {} }:
let
crosspkgs = pkgs.pkgsCross.i686-embedded;
in
pkgs.mkShell {
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = with pkgs; [
        zig
        binutils
        libgcc
        nasm
        gnumake
        clang
        bison
        flex
        gmp
        mpfr
        mpc
        texinfo
        # crosspkgs.gcc
    ];
}
