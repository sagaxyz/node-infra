#!/bin/bash

# shellcheck disable=SC2034
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

print_usage() {
    echo "Usage: $1 [network] [dev_account_key]"
    echo "E.g.: $1 testnet default-key"
}

print_info() {
    echo "[INFO] $1"
}

print_error() {
    echo "[ERROR] $1"
}

if [ $# -ne 2 ]; then
    print_usage $0
    exit 0
fi
network=$1
dev_account=$2
service_cluster=${SERVICE_CLUSTER:-srv1}

print_info "Port forwarding to prometheus"
kubeconfig="$HOME/.kube/${network}-${service_cluster}"
if [ ! -f $kubeconfig ]; then
  print_error "Kubeconfig file not found ($kubeconfig). Exiting."
  exit 1
fi
kubectl --kubeconfig $kubeconfig port-forward service/prometheus-k8s -n sagasrv-metrics 9090:9090 > /dev/null &
pid=$!
sleep 2

print_info "Fetching list of jailed validators"
json_output=$(curl -s 'http://localhost:9090/api/v1/query' --data-urlencode 'query=cosmos_validators_jailed == 1')

print_info "Terminating port-forward"
kill $pid >/dev/null 2>&1

if ! jq -e . <<< "$json_output" > /dev/null; then
  print_error "Invalid JSON output. Exiting."
  exit 1
fi

# shellcheck disable=SC2207
chain_ids=($(echo "$json_output" | jq -r '.data.result[] | "\(.metric.chainId)"'))
# shellcheck disable=SC2207
monikers=($(echo "$json_output" | jq -r '.data.result[] | "\(.metric.moniker)"'))

if [ ${#chain_ids[@]} -eq 0 ]; then
  print_info "Empty jailed validator list"
  exit 0
fi

array_length=${#chain_ids[@]}
for ((i = 0; i < array_length; i++)); do
  chain_id="${chain_ids[$i]}"
  moniker="${monikers[$i]}"
  
  echo "======= [$network] Unjailing $moniker for $chain_id ======="
  inventory_file=ansible/prod/$network/$moniker.yml
  ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbooks/utils/unjail-validator.yaml -i $inventory_file --extra-vars "dev_account=$dev_account chain_id=$chain_id"
done


