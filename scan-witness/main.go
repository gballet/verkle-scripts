package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pk910/dynamic-ssz"
)

func main() {
	f, err := os.Open(os.Args[1])
	if err != nil {
		panic(err)
	}

	var buf [8]byte
	var size uint64
	var blocknum uint64
	maxstatediffs, minstatediffs, statediffcount := 0, 100000, 0
	blockcount := 0
	defer func() {
		fmt.Printf("state diffs: min=%d max=%d, avg=%d\n", minstatediffs, maxstatediffs, statediffcount/blockcount)
	}()
	for err != io.EOF {
		n, err := f.Read(buf[:])
		if n != 8 {
			fmt.Println("could not read block number")
			return
		}
		if err != nil {
			log.Fatalf("error reading file: %v", err)
		}
		blocknum = binary.LittleEndian.Uint64(buf[:])

		n, err = f.Read(buf[:])
		if n != 8 {
			log.Fatalf("could not read witness size")
		}
		if err != nil {
			log.Fatalf("error reading file: %v", err)
		}
		size = binary.LittleEndian.Uint64(buf[:])

		encoded := make([]byte, size)
		n, err = f.Read(encoded)
		if n != int(size) {
			log.Fatalf("could not read the %d bytes of the witness from the file", size)
		}
		if err != nil && err != io.EOF {
			log.Fatalf("error reading file: %v", err)
		}

		ew := types.ExecutionWitness{}
		d := dynssz.NewDynSsz(map[string]any{})
		d.UnmarshalSSZ(&ew, encoded)

		if len(ew.StateDiff) < minstatediffs {
			minstatediffs = len(ew.StateDiff)
		}
		if len(ew.StateDiff) > maxstatediffs {
			maxstatediffs = len(ew.StateDiff)
		}
		statediffcount += len(ew.StateDiff)

		keysize := 0
		presize := 0
		postsize := 0
		for _, statediff := range ew.StateDiff {
			keysize += 31 + len(statediff.Updates)
			keysize += 31 + len(statediff.Reads)
			keysize += 31 + len(statediff.Inserts)
			keysize += 31 + len(statediff.Missing)

			presize += len(statediff.Updates) * 32
			presize += len(statediff.Reads) * 32

			postsize += len(statediff.Updates) * 32
			postsize += len(statediff.Inserts) * 32

		}

		vpsize := len(ew.VerkleProof.OtherStems)*31 +
			len(ew.VerkleProof.CommitmentsByPath)*32 +
			len(ew.VerkleProof.DepthExtensionPresent) +
			32 + // D
			32 + // FinalEvaluation
			2*8*32 // C_L, C_R

		fmt.Printf("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n", blocknum, keysize, size, 100*uint64(keysize)/size, presize, 100*uint64(presize)/size, postsize, 100*uint64(postsize)/size, vpsize, 100*uint64(vpsize)/size, len(ew.StateDiff))
		blockcount++
	}
}
