#!/bin/sh
# A simple script to try the transition code.

rm -rf .preimages
tar xfj preimages.tbz2

go build ./cmd/geth && ./geth --datadir=.preimages  --cache.preimages=true import next_blocks4
