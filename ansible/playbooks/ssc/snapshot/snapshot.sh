#!/bin/bash

RPC_ENDPOINT=${RPC_ENDPOINT:-"http://localhost:26657"}
BLOCKS_THRESHOLD=${BLOCKS_THRESHOLD:-10}
POLLING_INTERVAL_SEC=${POLLING_INTERVAL_SECS:-60}
INITIAL_SLEEP_SEC=${INITIAL_SLEEP_SEC:-180}
PRUNING_STRATEGY=${PRUNING_STRATEGY:-"default"}

print_info() {
    echo -e "[SNAPSHOT][INFO] $1"
}

print_error() {
    echo -e "[SNAPSHOT][ERROR] $1"
}

print_info "Initializing SSC"
rm -r ~/.ssc/config
sscd init $HOSTNAME --chain-id $CHAINID
rm ~/.ssc/config/genesis.*
wget -P ~/.ssc/config $GENESIS_URL
sed -i "s/persistent_peers = \"\"/persistent_peers = \"$PERSISTENT_PEERS\"/g" ~/.ssc/config/config.toml
sed -i "s/addr_book_file = .*/addr_book_file = \"data\/addrbook.json\"/g" ~/.ssc/config/config.toml

print_info "Start full node in the background"
sscd start --pruning $PRUNING_STRATEGY &
SSCD_PID=$!

print_info "Installing required packages"
apk add --no-cache curl jq aws-cli

print_info "Wait $INITIAL_SLEEP_SEC seconds for the node"
sleep $INITIAL_SLEEP_SEC

while true; do
    # Fetch the sync state
    consensus_height=$(curl -s $RPC_ENDPOINT/dump_consensus_state | jq -r '.result.peers[0].peer_state.round_state.height')
    last_committed_block=$(curl -s $RPC_ENDPOINT/commit | jq -r '.result.signed_header.commit.height')
    blocks_behind=$((consensus_height - last_committed_block))

    if ! [[ "$last_committed_block" =~ ^[0-9]+$ ]] || ! [[ "$consensus_height" =~ ^[0-9]+$ ]]; then
        print_error "Unable to get sync state"
    elif [[ $blocks_behind -lt $BLOCKS_THRESHOLD ]]; then
        # Check if in sync
        print_info "Full node in sync: $last_committed_block / $consensus_height"
        print_info "Stopping full node"
        kill $SSCD_PID
        sleep 60
        
        print_info "Creating tar file..."
        file_name=${CHAINID}_${last_committed_block}.tar
        local_file_name=/tmp/$file_name
        if ! tar cf $local_file_name ~/.ssc/data; then
            print_error "Cannot create tar file"
        else
            print_info "Uploading tar file..."
            aws s3 cp $local_file_name $S3_SNAPSHOTS_BUCKET/$file_name
            
            # latest txt file
            print_info "Copying to latest.tar"
            aws s3 cp $S3_SNAPSHOTS_BUCKET/$file_name $S3_SNAPSHOTS_BUCKET/latest.tar
            print_info "Uploading latest txt file"
            echo $file_name > /tmp/latest
            aws s3 cp /tmp/latest $S3_SNAPSHOTS_BUCKET/latest

            print_info "Deleting tar file locally"
            rm $local_file_name

            print_info "Deleting older tar file remotely"
            # Getting the height of the snapshots stored in s3
            snapshot_heights=$(aws s3 ls $S3_SNAPSHOTS_BUCKET/ | sed 's/.* //g' | grep "^${CHAINID}_" | sed "s/${CHAINID}_//" | sed "s/\..*//" | sort -n)
            # shellcheck disable=SC2181
            if [[ $? -ne 0 ]] || [[ -z "$snapshot_heights" ]]; then
                print_info "No remote file to remove"
                break
            fi
            # shellcheck disable=SC2206
            snapshot_heights_array=($snapshot_heights)
            snapshots_count=$(echo "${snapshot_heights_array[@]}" | wc -w)
            snapshots_to_remove=$((snapshots_count - S3_SNAPSHOTS_RETENTION))
            print_info "Retention: $S3_SNAPSHOTS_RETENTION. Files: $snapshots_count"

            # remove older snapshot(s) from the sorted array
            for ((i=0; i<snapshots_to_remove; i++)); do
                old_snapshot_name=${CHAINID}_${snapshot_heights_array[$i]}.tar
                print_info "Removing $old_snapshot_name"
                aws s3 rm $S3_SNAPSHOTS_BUCKET/$old_snapshot_name
            done
        fi

        break
    else
        print_info "Sync state: $last_committed_block / $consensus_height => $blocks_behind blocks behind"
    fi

    # Check if SSC is still running
    if [ ! -d "/proc/$SSCD_PID" ]; then
        print_error "SSC is not running. Aborting"
        exit 1
    fi

    # Wait before polling again
    sleep $POLLING_INTERVAL_SEC
done

print_info "Done"