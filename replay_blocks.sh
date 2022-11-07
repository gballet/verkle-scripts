#!/bin/sh

REPLAYDIR=$HOME/src/geth-replay

pushd $HOME/src/go-ethereum && pushd ~ && rm -rf preimages_small/.preimages && tar xfj preimages.tbz2 -C preimages_small && popd && go build ./cmd/geth/ && ./geth verkle to-verkle --datadir=$HOME/preimages_small/.preimages && popd
pushd $REPLAYDIR && go build ./cmd/geth/ && ./geth import --datadir=$HOME/preimages_small/.preimages next_blocks4 && popd
pushd $REPLAYDIR && go tool pprof -png cpu.out && popd
