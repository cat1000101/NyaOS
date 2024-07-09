set -x
set -e

./clean.sh

zig build all

qemu-system-i386 -debugcon stdio -cdrom zig-out/NyaOS.iso