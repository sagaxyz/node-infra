#!/bin/bash
PROXY_URL="https://ethproxy.jsonrpc.testnet.sagarpc.io"
NEW_NODE_URL="http://localhost:8545"
OLD_NODE_URL="https://sagaevm-54647357-1.jsonrpc.testnet.sagarpc.io"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test address and block hash for various methods
TEST_ADDRESS="0xa459Cb1EC2FDD0Dbd419D7921669dDd8F44DA91C"
TEST_BLOCK_HASH="0xBFF98A131698FEB7BB26B31CBEB042570AF093D2BCFBEBB2D372C6C86E7D1B6B"
TEST_TX_HASH="0xaadbf1d4c5aa2d22bf40cbcb8be7d1e038e5d416e74a5e9f18d0729533ed0a5a"

# Function to make RPC calls
make_rpc_call() {
    local url=$1
    local method=$2
    local params=$3
    curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" "$url"
}

# Function to compare results
compare_results() {
    local method=$1
    local params=$2
    # echo "Testing $method..."
    
    # Get results from all three endpoints
    local proxy_result=$(make_rpc_call "$PROXY_URL" "$method" "$params")
    local new_node_result=$(make_rpc_call "$NEW_NODE_URL" "$method" "$params")
    local old_node_result=$(make_rpc_call "$OLD_NODE_URL" "$method" "$params")
    
    # Check for empty results
    if [ -z "$proxy_result" ] || [ -z "$new_node_result" ] || [ -z "$old_node_result" ]; then
        echo -e "${YELLOW}$method (Empty result detected)${NC}"
        echo "Proxy result: $proxy_result"
        echo "New node result: $new_node_result"
        echo "Old node result: $old_node_result"
        echo "----------------------------------------"
        return
    fi
    
    # Compare results
    if [ "$proxy_result" = "$old_node_result" ]; then
        echo -e "${GREEN}$method${NC}"
    else
        echo -e "${RED}$method${NC}"
        echo "Proxy result: $proxy_result"
        echo "New node result: $new_node_result"
        echo "Old node result: $old_node_result"
        echo "----------------------------------------"
    fi
}

# Block methods
# compare_results "eth_blockNumber" "[]"
# compare_results "eth_getBlockByNumber" "[\"latest\", true]"
compare_results "eth_getBlockByHash" "[\"$TEST_BLOCK_HASH\", true]"

# Transaction methods
compare_results "eth_getTransactionByHash" "[\"$TEST_TX_HASH\"]"
# compare_results "eth_getTransactionCount" "[\"$TEST_ADDRESS\", \"latest\"]"
compare_results "eth_getTransactionReceipt" "[\"$TEST_TX_HASH\"]"
# compare_results "eth_getBlockTransactionCountByHash" "[\"$TEST_BLOCK_HASH\"]"
# compare_results "eth_getBlockTransactionCountByNumber" "[\"latest\"]"
compare_results "eth_getTransactionByBlockHashAndIndex" "[\"$TEST_BLOCK_HASH\", \"0x0\"]"
compare_results "eth_getTransactionByBlockNumberAndIndex" "[\"latest\", \"0x0\"]"
# compare_results "eth_sendRawTransaction" "[\"0x1234567890\"]"
# compare_results "eth_sendTransaction" "[{\"from\":\"$TEST_ADDRESS\",\"to\":\"$TEST_ADDRESS\",\"value\":\"0x0\"}]"

# Account methods
# compare_results "eth_accounts" "[]"
# compare_results "eth_getBalance" "[\"$TEST_ADDRESS\", \"latest\"]"
# compare_results "eth_getStorageAt" "[\"$TEST_ADDRESS\", \"0x0\", \"latest\"]"
# compare_results "eth_getCode" "[\"$TEST_ADDRESS\", \"latest\"]"
# compare_results "eth_getProof" "[\"$TEST_ADDRESS\", [\"0x0\"], \"latest\"]"
compare_results "eth_call" "[{\"from\":\"$TEST_ADDRESS\",\"to\":\"$TEST_ADDRESS\",\"value\":\"0x0\"}, \"latest\"]"

# Protocol methods
# compare_results "eth_protocolVersion" "[]"
compare_results "eth_gasPrice" "[]"
compare_results "eth_estimateGas" "[{\"from\":\"$TEST_ADDRESS\",\"to\":\"$TEST_ADDRESS\",\"value\":\"0x0\"}]"
compare_results "eth_feeHistory" "[\"0x4\", \"latest\", [0.1, 0.5, 0.9]]"
# compare_results "eth_maxPriorityFeePerGas" "[]"
# compare_results "eth_chainId" "[]"

# Uncle methods
# compare_results "eth_getUncleByBlockHashAndIndex" "[\"$TEST_BLOCK_HASH\", \"0x0\"]"
# compare_results "eth_GetUncleByBlockNumberAndIndex" "[\"latest\", \"0x0\"]"
# compare_results "eth_getUncleCountByBlockHash" "[\"$TEST_BLOCK_HASH\"]"
# compare_results "eth_GetUncleCountByBlockNumber" "[\"latest\"]"

# Network methods
# compare_results "eth_hashrate" "[]"
# compare_results "eth_mining" "[]"
# compare_results "eth_syncing" "[]"
compare_results "eth_coinbase" "[]"

# Signing methods
# compare_results "eth_sign" "[\"$TEST_ADDRESS\", \"0x1234567890\"]"
# compare_results "eth_getTransactionLogs" "[{\"address\":\"$TEST_ADDRESS\"}]"
# compare_results "eth_signTypedData" "[\"$TEST_ADDRESS\", {\"types\":{\"EIP712Domain\":[]},\"primaryType\":\"EIP712Domain\",\"domain\":{},\"message\":{}}]"
# compare_results "eth_resend" "[{\"from\":\"$TEST_ADDRESS\",\"to\":\"$TEST_ADDRESS\",\"value\":\"0x0\"}, \"latest\"]"
# compare_results "eth_getPendingTransactions" "[]"

