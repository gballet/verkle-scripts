package main

import (
	"bytes"
	"fmt"

	"github.com/ethereum/go-verkle"
	"github.com/syndtr/goleveldb/leveldb"
	"github.com/syndtr/goleveldb/leveldb/opt"
	"github.com/syndtr/goleveldb/leveldb/util"
)

// used to delete a key range we don't need for data collection
func deleteUselessKeyRanges(db *leveldb.DB, rg []byte) {
	delIter := db.NewIterator(util.BytesPrefix(rg), nil)
	for delIter.First(); delIter.Valid(); delIter.Next() {
		// safeguard: ensure that the key starts with the block prefix
		// so that we don't accidentally delete stuff
		if bytes.Equal(delIter.Key()[:len(rg)], rg) {
			db.Delete(delIter.Key(), nil)
		}
	}
	db.CompactRange(*util.BytesPrefix(rg))
}

func main() {
	db, err := leveldb.OpenFile("/chains/.ethereum_hash/geth/chaindata", &opt.Options{})
	// db, err := leveldb.OpenFile("/chains/.ethereum_hash/geth/chaindata", &opt.Options{ReadOnly: true})
	if err != nil {
		panic(err)
	}
	defer db.Close()

	// Variable to store the total size of the values
	prefix := []byte("flat-")
	var (
		totalSize int

		totalInternal int
		internalSize  int

		totalBitmap int
		bitmapSize  int

		totalEoA int
		eoaSize  int

		totalSingle int
		singleSize  int

		totalSkipList int
		skiplistSize  int

		savedSkipList int

		singleLeftZeros int

		// List of depths that a leaf is found at
		depths = make(map[int]int)

		counter     = 0
		leafCounter = 0

		zeroCount = 0
		zero32    [32]byte
	)

	// Delete account and storage tries
	fmt.Println("Deleting account tries")
	deleteUselessKeyRanges(db, []byte("A"))
	fmt.Println("Deleting storage tries")
	deleteUselessKeyRanges(db, []byte("O"))
	fmt.Println("Deleting block bodies")
	deleteUselessKeyRanges(db, []byte("b"))
	fmt.Println("Deleting receipts")
	deleteUselessKeyRanges(db, []byte("r"))
	fmt.Println("Deleting Blooms")
	deleteUselessKeyRanges(db, []byte("B"))
	fmt.Println("Deleting tx index")
	deleteUselessKeyRanges(db, []byte("l"))

	// Create an iterator for keys starting with the given prefix
	iter := db.NewIterator(util.BytesPrefix(prefix), nil)

	// Iterate through the database for keys with the given prefix
	for iter.First(); iter.Valid(); iter.Next() {
		counter++
		totalSize += len(iter.Value())
		firstByte := iter.Value()[0]
		switch firstByte {
		case 1:
			totalInternal++
			internalSize += len(iter.Value())
		case 2:
			totalBitmap++
			bitmapSize += len(iter.Value())

			depth := len(iter.Key()) - len("flat-")
			depths[depth] = depths[depth] + 1
			leafCounter++
		case 3:
			totalEoA++
			eoaSize += len(iter.Value())

			depth := len(iter.Key()) - len("flat-")
			depths[depth] = depths[depth] + 1
			leafCounter++
		case 4:
			totalSingle++
			singleSize += len(iter.Value())

			slot := iter.Value()[len(iter.Value())-32:]
			for i := 0; i < 32; i++ {
				if slot[i] != 0 {
					break
				}
				singleLeftZeros++
			}
			// remove the size taken by a counter,
			// althgough we _could_ stuff it in the
			// head byte.
			if singleLeftZeros > 0 {
				singleLeftZeros -= 1
			}

			depth := len(iter.Key()) - len("flat-")
			depths[depth] = depths[depth] + 1
			leafCounter++
		case 8:
			totalSkipList++

			savedSkipList += 32 - len(iter.Value())%32
			skiplistSize += len(iter.Value())

			depth := len(iter.Key()) - len("flat-")
			depths[depth] = depths[depth] + 1
			leafCounter++
		default:
			fmt.Println("invalid type", firstByte)
			panic("invalid type")
		}
		n, err := verkle.ParseNode(iter.Value(), 0)
		if err != nil {
			panic(err)
		}
		leaf, ok := n.(*verkle.LeafNode)
		if ok {
			for _, v := range leaf.Values() {
				if bytes.Equal(v[:], zero32[:]) {
					zeroCount++
				}
			}
		}
		if counter%1_000_000 == 0 {
			fmt.Println("accumulated", totalSize, "bytes (", totalSize/(1024*1024*1024), "G), scanned", counter, "keys")
		}
	}
	iter.Release()

	fmt.Println("found", totalSize, "bytes, ", savedSkipList, "bytes saved with skiplists")
	fmt.Println(singleLeftZeros, "bytes could be saved with left-trim")
	fmt.Printf("%-10s %-15s %-15s\n", "Type", "Count", "Size")
	fmt.Println("----------------------------------------")
	fmt.Printf("%-10s %-15d %-15d\n", "Branch", totalInternal, internalSize)
	fmt.Printf("%-10s %-15d %-15d\n", "Bitmap", totalBitmap, bitmapSize)
	fmt.Printf("%-10s %-15d %-15d\n", "EoA", totalEoA, eoaSize)
	fmt.Printf("%-10s %-15d %-15d\n", "Single", totalSingle, singleSize)
	fmt.Printf("%-10s %-15d %-15d\n", "Skiplist", totalSkipList, skiplistSize)

	fmt.Println("")
	fmt.Printf("%-3s %-10s %s\n", "Depth", "Count", "%")
	fmt.Println("--------------------------")
	for depth, count := range depths {
		fmt.Printf("%-3d %-10d %d%%\n", depth, count, 100*count/leafCounter)
	}

	fmt.Printf("\n\n%d leaves are 0\n", zeroCount)
}
