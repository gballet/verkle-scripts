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
			internalSize += len(iter.Value())
		case 2:
			totalBitmap++
			bitmapSize += len(iter.Value())
		case 3:
			totalEoA++
			eoaSize += len(iter.Value())
		case 4:
			totalSingle++
			singleSize += len(iter.Value())
		case 8:
			totalSkipList++

			savedSkipList += 32 - len(iter.Value())%32
			skiplistSize += len(iter.Value())
		default:
			fmt.Println("invalid type", firstByte)
			panic("invalid type")
		}
		if counter%1_000_000 == 0 {
			fmt.Println("accumulated", totalSize, "bytes (", totalSize/(1024*1024*1024), "G), scanned", counter, "keys")
		}
	}
	iter.Release()

	fmt.Println("found", totalSize, "bytes, ", savedSkipList, "bytes saved with skiplists")
	fmt.Printf("%-10s %-15s %-15s\n", "Type", "Count", "Size")
	fmt.Println("----------------------------------------")
	fmt.Printf("%-10s %-15d %-15d\n", "Branch", totalInternal, internalSize)
	fmt.Printf("%-10s %-15d %-15d\n", "Bitmap", totalBitmap, bitmapSize)
	fmt.Printf("%-10s %-15d %-15d\n", "EoA", totalEoA, eoaSize)
	fmt.Printf("%-10s %-15d %-15d\n", "Single", totalSingle, singleSize)
	fmt.Printf("%-10s %-15d %-15d\n", "Skiplist", totalSkipList, skiplistSize)
}
