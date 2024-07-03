{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  name = "osdev";
  nativeBuildInputs = with pkgs; [
    getopt
    flex
    bison
    bc
    pkg-config
  ];
  buildInputs = with pkgs; [
    elfutils
    ncurses
    openssl
    zlib
    nasm
    zig
    binutils
    gcc
    gnumake
  ];
}