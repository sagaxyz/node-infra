#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Output file
OUTPUT_FILE="tx_details.csv"
COSMOS_RPC_ENDPOINT="https://sagaevm-5464-1-cosmosrpc.jsonrpc.spsrv1.sagarpc.io:443"

# Write CSV header
echo "timestamp,block_number,tx_hash,gas_wanted,gas_used,spender,fees_amount,fees_denom" > "$OUTPUT_FILE"

# Loop through blocks
start=1622252 # 1639532
end=1641850
# start=1639532
# end=1639540
for block_num in $(jot - $start $end); do
    block_data=$(sagaosd --node $COSMOS_RPC_ENDPOINT query txs --events "tx.height=$block_num")
    tx_count=$(echo "$block_data" | yq -r '.count')
    
    if [ "$tx_count" -gt 0 ]; then
        # Iterate through each transaction
        for i in $(seq 0 $((tx_count-1))); do
            gas_wanted=$(echo "$block_data" | yq -r ".txs[$i].gas_wanted")
            gas_used=$(echo "$block_data" | yq -r ".txs[$i].gas_used")
            timestamp=$(echo "$block_data" | yq -r ".txs[$i].timestamp")
            tx_hash=$(echo "$block_data" | yq -r ".txs[$i].txhash")
            spender=$(echo "$block_data" | yq -r ".txs[$i].events[2].attributes[0].value")
            fees=$(echo "$block_data" | yq -r ".txs[$i].events[2].attributes[1].value")
            fees_amount=$(echo "$fees" | sed 's/[^0-9]*//g')
            fees_denom=$(echo "$fees" | sed 's/[0-9]*//g')
            # echo "Block $block_num, TX $i:"
            # echo "  Gas Wanted: $gas_wanted"
            # echo "  Gas Used: $gas_used"
            # echo "  Timestamp: $timestamp"
            # echo "  Hash: $tx_hash"
            # echo "  Spender: $spender"
            # echo "  Fees: $fees_amount - $fees_denom"
            # echo "----------------------------------------"

            # Write transaction details to CSV
            # echo "$timestamp,$block_num,$tx_hash,$gas_wanted,$gas_used,$spender,$fees_amount,$fees_denom" >> "$OUTPUT_FILE"
        done
    fi
    printf "${GREEN}Processed block %d: %d txs${NC}\n" "$block_num" "$tx_count"
done
