set -xe

rm -rf zig-out .zig-cache

zig build debug | tee .extras/run.log