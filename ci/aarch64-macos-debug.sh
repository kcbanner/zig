#!/bin/sh

set -x
set -e

# Script assumes the presence of the following:
# s3cmd

ZIGDIR="$(pwd)"
TARGET="$ARCH-macos-none"
MCPU="baseline"

cd $ZIGDIR

curl -O https://ziglang.org/builds/zig-macos-aarch64-0.11.0-dev.4006+bf827d0b5.tar.xz
tar xf zig-macos-aarch64-0.11.0-dev.4006+bf827d0b5.tar.xz
ZIG=$(pwd)/zig-macos-aarch64-0.11.0-dev.4006+bf827d0b5/zig

cd test/standalone/stack_iterator
#$ZIG build test --zig-lib-dir "$ZIGDIR/lib" -Dtarget=$TARGET -Dcpu=$MCPU
$ZIG test --zig-lib-dir "$ZIGDIR/lib" $ZIGDIR/temp/test_incorrect_pointer_alignment.zig -funwind-tables
