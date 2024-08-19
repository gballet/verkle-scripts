# This scripts queries etherscan to recover the gas used by every transaction in a block
import requests

# Replace with your Etherscan API key
ETHERSCAN_API_KEY = 'your api key'

def get_block_transactions(block_number):
    url = f"https://api.etherscan.io/api"
    params = {
        "module": "proxy",
        "action": "eth_getBlockByNumber",
        "tag": hex(17165311),
        "boolean": "true",
        "apikey": ETHERSCAN_API_KEY
    }
    
    response = requests.get(url, params=params)
    if response.status_code == 200:
        block_data = response.json()
        #print(block_data)
        if block_data['result'] is not None:
            return block_data['result']['transactions']
        else:
            raise Exception(f"Etherscan API error: {block_data['message']}")
    else:
        raise Exception(f"Error fetching data from Etherscan: {response.status_code}")

def get_total_gas_usage(transactions):
    total_gas_used = 0
    for tx in transactions:
        # Convert the gas used from hex to decimal
        receipt = get_transaction_receipt(tx['hash'])
        print(tx['hash'], ',', int(receipt['gasUsed'], 16))

def get_transaction_receipt(tx_hash):
    url = f"https://api.etherscan.io/api"
    params = {
        "module": "proxy",
        "action": "eth_getTransactionReceipt",
        "txhash": tx_hash,
        "apikey": ETHERSCAN_API_KEY
    }
    
    response = requests.get(url, params=params)
    if response.status_code == 200:
        receipt_data = response.json()
        if receipt_data['result']:
            return receipt_data['result']
        else:
            raise Exception(f"Etherscan API error: {receipt_data['message']}")
    else:
        raise Exception(f"Error fetching data from Etherscan: {response.status_code}")

def main(block_number):
    transactions = get_block_transactions(block_number)
    get_total_gas_usage(transactions)
    # print(f"Total gas used in block {block_number}: {total_gas_used}")

if __name__ == "__main__":
    # Replace with the block number you're interested in
    block_number = 17000000
    main(block_number)
