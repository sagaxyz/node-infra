#!/bin/bash
OPTS=${OPTS:-'--json-rpc.api eth,txpool,personal,net,debug,web3 --api.enabled-unsafe-cors --api.enable --grpc.address 0.0.0.0:9090 --json-rpc.address 0.0.0.0:8545 --json-rpc.enable true --json-rpc.api true --json-rpc.ws-address 0.0.0.0:8546 --json-rpc.gas-cap 50000000'}
SNAPSHOT_TRUST_INTERVAL=${SNAPSHOT_TRUST_INTERVAL:-1000}
BOND_DENOM=${BOND_DENOM:-stake}
MINIMUM_GAS_PRICES=0.0001${DENOM},0.0001${BOND_DENOM}
MEMPOOL_SIZE=${MEMPOOL_SIZE:-500}
LOG_LEVEL=${LOG_LEVEL:-info}
CONFIG_DIR=$HOME/.sagaosd/config
CONFIG_FILE=$CONFIG_DIR/config.toml
APP_CONFIG_FILE=$CONFIG_DIR/app.toml

Logger()
{
	MSG=$1
	echo "$(date) $MSG"
}

ExitOnError() {
    local EXIT_CODE=$1
    local ERROR_MSG=$2
    if [ $EXIT_CODE -ne 0 ]; then
        Logger "Error: $ERROR_MSG"
        exit $EXIT_CODE
    fi
}

ConfigureStateSync()
{
  ValidateEnvVar "SYNC_RPC"
  ValidateEnvVar "SNAPSHOT_TRUST_INTERVAL"

  Logger "Starting function ConfigureStartFromStateSync"
  RPC_SERVER=$(echo $SYNC_RPC|awk -F"," '{gsub("tcp","http",$1);print $1}')
  CURRENT_BLOCK=$(curl -s "$RPC_SERVER"/status | jq '.result.sync_info.latest_block_height'| awk 'gsub("\"","",$0)')
  if [ -z "$CURRENT_BLOCK" ]; then
    Logger "Unable to fetch current block. Skipping state-sync config"
    Logger "Exiting function ConfigureStartFromStateSync"
    exit 2
  fi
  Logger "Current Block: $CURRENT_BLOCK"
  TRUST_HEIGHT=$((CURRENT_BLOCK-SNAPSHOT_TRUST_INTERVAL)) # Take the current block - SNAPSHOT_TRUST_INTERVAL as the start height
  if [ "$TRUST_HEIGHT" -lt 0 ]; then
    Logger "Not enough blocks to set trust height"
    Logger "Exiting function ConfigureStartFromStateSync"
    exit 2
  fi
  Logger "Trust Height: $TRUST_HEIGHT"
  TRUST_BLOCK=$(curl -s "$RPC_SERVER"/block\?height=$TRUST_HEIGHT)
  if [ -z "$TRUST_BLOCK" ]; then
    Logger "Unable to fetch trust block. Skipping state-sync config"
    Logger "Exiting function ConfigureStartFromStateSync"
    exit 2
  fi
  Logger "Trust Block: $TRUST_BLOCK"
  TRUST_HASH=$(curl -s "$RPC_SERVER"/block\?height=$TRUST_HEIGHT | jq -r '.result.block_id.hash')
  if [ -z "$TRUST_HASH" ]; then
    Logger "Unable to fetch trust hash. Skipping state-sync config"
    Logger "Exiting function ConfigureStartFromStateSync"
    exit 2
  fi
  Logger "Trust Hash: $TRUST_HASH"
  Logger "Peers: $PEERS"
  sed -i -e '/enable =/ s/= .*/= true/' $CONFIG_FILE
  sed -i -e "/trust_height =/ s/= .*/= $TRUST_HEIGHT/" $CONFIG_FILE
  sed -i -e "/trust_hash =/ s/= .*/= \"$TRUST_HASH\"/" $CONFIG_FILE
  sed -i -e "/rpc_servers =/ s^= .*^= \"$SYNC_RPC\"^" $CONFIG_FILE
  sed -i -e "/seeds =/ s/= .*/= \"$PEERS\"/" $CONFIG_FILE
  Logger "Exiting function ConfigureStartFromStateSync"
}

UpdateTomlConfigs()
{
  Logger "Starting function UpdateTomlConfigs"
  sed -i "s/persistent_peers = \"\"/persistent_peers = \"$PEERS\"/g" $CONFIG_FILE

  # Reduce iavl-cache-size
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/iavl-cache-size = .*/iavl-cache-size = 100000/g' $APP_CONFIG_FILE
  else
    sed -i 's/iavl-cache-size = .*/iavl-cache-size = 100000/g' $APP_CONFIG_FILE
  fi
  # support cors
  sed -i 's/^cors_allowed_origins = .*/cors_allowed_origins = ["*"]/g' $CONFIG_FILE
  sed -i 's/^enabled-unsafe-cors =.*/enabled-unsafe-cors = true/g' $APP_CONFIG_FILE
  sed -i 's/^enable-unsafe-cors =.*/enable-unsafe-cors = true/g' $APP_CONFIG_FILE

  # allow api (if enabled)
  sed -i 's/^swagger =.*$/swagger = true/g' $APP_CONFIG_FILE
  sed -i 's/^address = ".*:\/\/.*:1317"$/address = "tcp:\/\/0.0.0.0:1317"/g' $APP_CONFIG_FILE

  # disable produce empty block
  sed -i 's/create_empty_blocks = true/create_empty_blocks = false/g' $CONFIG_FILE
  sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' $CONFIG_FILE
  sed -i 's/addr_book_strict = true/addr_book_strict = false/g' $CONFIG_FILE
  sed -i 's/prometheus = false/prometheus = true/g' $CONFIG_FILE
  sed -i 's/allow_duplicate_ip = false/allow_duplicate_ip = true/g' $CONFIG_FILE
  sed -i 's/send_rate = 5120000/send_rate = 20000000/g' $CONFIG_FILE
  sed -i 's/recv_rate = 5120000/recv_rate = 20000000/g' $CONFIG_FILE
  sed -i 's/max_packet_msg_payload_size = 1024.*/max_packet_msg_payload_size = 10240/g' $CONFIG_FILE
  sed -i 's/flush_throttle_timeout = \"100ms\"/flush_throttle_timeout = \"10ms\"/g' $CONFIG_FILE

  # mempool size
  sed -i "s/^size = .*/size = \"$MEMPOOL_SIZE\"/g" $CONFIG_FILE

  Logger "Exiting function UpdateTomlConfigs"
}

Init() {
    Logger "Starting function Init"

    sagaosd init $MONIKER --chain-id $CHAIN_ID
    ExitOnError $? "Failed to initialize sagaosd"

    Logger "Exiting function Init"
}

InitGenesis() {
    Logger "Starting function InitGenesis"

    if [ ! -f "$HOME/.sagaosd/data/genesis.json" ]; then
        Logger "Downloading genesis file: $GENESIS_URL"
        curl -s $GENESIS_URL > $HOME/.sagaosd/data/genesis.json
        ExitOnError $? "Failed to download genesis file from $GENESIS_URL"
    fi

    Logger "Copying genesis file from data to config directory"
    cp "$HOME/.sagaosd/data/genesis.json" "$HOME/.sagaosd/config/genesis.json"
    ExitOnError $? "Failed to move genesis file from data to config directory"

    Logger "Exiting function InitGenesis"
}

ShouldInit() {
    Logger "Starting function ShouldInit"

    if [ -f "$CONFIG_DIR/genesis.json" ]; then
        Logger "Genesis file exists under config directory, no initialization needed"
        return 1
    fi

    Logger "Genesis file not found under config directory, initialization needed"
    Logger "Exiting function ShouldInit"
    return 0
}

Start() {
    Logger "Starting function Start"
    sagaosd start --pruning=$PRUNING --log_level=$LOG_LEVEL --minimum-gas-prices=$MINIMUM_GAS_PRICES $OPTS
    Logger "Exiting function Start"
}

ValidateEnvVar()
{
  local ENVVAR=$1
  local EXITIFUNSET=${2:-1}  # exit if env var is not set. Pass 1 for true, 0 for false i.e. if 0, script will continue executing. Default: True (exit)
  local ECHOVAL=${3:-1} # echo the value of the variable in a log entry. Pass 1 = true, 0 = false. Default: True (will echo)
  if [[ -z ${!ENVVAR} ]];
  then
    Logger "Environment variable $ENVVAR is not set"
    if [ $EXITIFUNSET -eq 1 ];
    then
      Logger "Exiting in error as environment variable $ENVVAR is not set"
      exit 1
    else
      Logger "Continuing even though environment variable $ENVVAR is not set"
    fi
  fi
  if [ $ECHOVAL -eq 1 ];
  then
    Logger "$ENVVAR: ${!ENVVAR}"
  fi
}

ValidateAndEchoEnvVars()
{
    ValidateEnvVar "CHAIN_ID"
    ValidateEnvVar "DENOM"
    ValidateEnvVar "GENESIS_URL"
    ValidateEnvVar "MONIKER"
    ValidateEnvVar "PRUNING"
    ValidateEnvVar "LOG_LEVEL"
    ValidateEnvVar "MINIMUM_GAS_PRICES"
    ValidateEnvVar "PEERS"
}

## Main
ValidateAndEchoEnvVars
if ShouldInit; then
  Init
  InitGenesis
fi
UpdateTomlConfigs

if [ -n "$SYNC_RPC" ]; then
  ConfigureStateSync
fi

Start
