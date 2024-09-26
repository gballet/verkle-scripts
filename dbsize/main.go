package main

import (
	"fmt"

	"github.com/syndtr/goleveldb/leveldb"
	"github.com/syndtr/goleveldb/leveldb/opt"
	"github.com/syndtr/goleveldb/leveldb/util"
)

func main() {
	db, err := leveldb.OpenFile("/chains/.ethereum_hash/geth/chaindata", &opt.Options{ReadOnly: true})
	if err != nil {
		panic(err)
	}
	defer db.Close()

	// Variable to store the total size of the values
	prefix := []byte("flat-")
	var (
		totalSize     int
		totalInternal int
		totalBitmap   int
		totalEoA      int
		totalSingle   int
		totalSkipList int

		savedSkipList int
	)

	// Create an iterator for keys starting with the given prefix
	iter := db.NewIterator(util.BytesPrefix(prefix), nil)
	counter := 0

	// Iterate through the database for keys with the given prefix
	for iter.First(); iter.Valid(); iter.Next() {
		counter++
		totalSize += len(iter.Value())
		firstByte := iter.Value()[0]
		switch firstByte {
		case 1:
			totalInternal++
		case 2:
			totalBitmap++
		case 3:
			totalEoA++
		case 4:
			totalSingle++
		case 8:
			totalSkipList++

			savedSkipList += 32 - len(iter.Value())%32
		default:
			fmt.Println("invalid type", firstByte)
			panic("invalid type")
		}
		if counter%1_000_000 == 0 {
			fmt.Println("accumulated", totalSize, "bytes (", totalSize/(1024*1024*1024), "G), scanned", counter, "keys")
		}
	}
	iter.Release()

	fmt.Println("found", totalSize, "bytes", "internal", totalInternal, "bitmap", totalBitmap, "EoA", totalEoA, "single slot", totalSingle, "skip list", totalSkipList, "(", savedSkipList, "bytes saved)")
}
