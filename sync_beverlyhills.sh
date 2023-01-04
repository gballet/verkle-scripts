#!/bin/sh

rm -rf eldata
mkdir eldata
$HOME/src/go-ethereum/geth --datadir=$PWD/eldata/ init $PWD/config/genesis.json
$HOME/src/go-ethereum/geth --datadir=/media/gballet/5fc66635-7186-4bf7-b32d-646d7190f8b5/beverlyhills/eldata/ --http --http.api="net,eth,debug,engine,web3" --ws --ws.api="net,eth,debug,engine,web3" --http.corsdomain="*" --networkid=90210 --syncmode=full --authrpc.addr=0.0.0.0 --authrpc.vhosts="*" --authrpc.jwtsecret=/tmp/jwtsecret --bootnodes="enode://80485311e1f22ab86630db23d5d77b7c67d535c7c2aa6df99f10b63250602b230093143b49b40640b227b97eb226c01eaed5a4eb5d66349d78371515b243f4cb@134.122.74.110:30303" &

sleep 10
echo "=== sending the sync commands ==="

echo "- new payload"
cat <<'END' | nc -U $PWD/eldata/geth.ipc -q 0
{
  "jsonrpc": "2.0",
  "method": "engine_newPayloadV1",
  "params": [
    {
      "parentHash": "0x5f6bbad101d987e35abf1b9c63ee1cf9ad52b1c1eaddcb4629b167ca02817183",
      "feeRecipient": "0xf97e180c050e5ab072211ad2c213eb5aee4df134",
      "stateRoot": "0x20b6dba95018738d22d7ae96207e922a7808d4a6db80847c8ca428196a523c34",
      "receiptsRoot": "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      "logsBloom": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      "prevRandao": "0xda0826ebd01f23a11f4fa04c7a8c23e3776f286c37bb7767dece0fcfa541c184",
      "blockNumber": "0x1ee8c",
      "gasLimit": "0x1c9c380",
      "gasUsed": "0x0",
      "timestamp": "0x63b47aa0",
      "extraData": "0x",
      "baseFeePerGas": "0x7",
      "blockHash": "0xcd9ec23b8c3d0ddecd7ca502c9c23aa820b01252a6260a6095ae1ea0f8211092",
      "transactions": []
    }
  ],
  "id": 758464
}
END

echo "- forkchoice update"
cat <<END | nc -U $PWD/eldata/geth.ipc -q 0
{
  "jsonrpc": "2.0",
  "method": "engine_forkchoiceUpdatedV1",
  "params": [
    {
      "headBlockHash": "0xcd9ec23b8c3d0ddecd7ca502c9c23aa820b01252a6260a6095ae1ea0f8211092",
      "safeBlockHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
      "finalizedBlockHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
    },
    null
  ],
  "id": 758465
}
END