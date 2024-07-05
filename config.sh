SYSTEM_HEADER_PROJECTS="libc kernel"
PROJECTS="libc kernel"

export MAKE=make
export HOST=${HOST:-$(./default-host.sh)}

export AR="zig ar"
export AS=nasm
export CC="zig cc -target x86-freestanding"

export PREFIX=/usr
export EXEC_PREFIX=$PREFIX
export BOOTDIR=/boot
export LIBDIR=$EXEC_PREFIX/lib
export INCLUDEDIR=$PREFIX/include

export CFLAGS='-O2 -g'
export CPPFLAGS=''

# Configure the cross-compiler to use the desired system root.
export SYSROOT="$(pwd)/sysroot"
export CC="$CC --sysroot=$SYSROOT -I$SYSROOT$INCLUDEDIR"
