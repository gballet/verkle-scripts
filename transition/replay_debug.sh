#!/bin/sh
# Same thing as replay.sh but with the debugger instead.

rm -rf .preimages
tar xfj preimages.tbz2

dlv debug ./cmd/geth -- --datadir=.preimages import ${1:="next_blocks4"}
