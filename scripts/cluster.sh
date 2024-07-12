#!/bin/bash

print_usage() {
    echo "Usage: $1 [command] [inventoryFile]"
    echo ""
    echo "command:"
    echo "  launch           Launch a brand new cluster"
    echo "  delete           Delete running cluster"
    echo "  relaunch         Delete and launch cluster"
    echo "  deploy           Deploy (or re-apply) the saga stack"
    echo "  sagactx          Configure sagacli and spcd to connect to the cluster defined in inventoryFile"
    echo "  kubeconfig       Update kubeconfig"
    echo "  updateTemplates  Update chainlet templates"
    echo "  localSetup       Setup local requirements"
    echo "  help             Print this guide"
    echo ""
    echo "inventory_file:"
    echo "  config yaml, e.g.: ansible/testnet/sp1.yml"
    echo ""
    exit 1
}

print_error() {
    echo >&2 "[ERROR] $1"; exit 1;
}

assert_command_installed () {
    hash $1 2>/dev/null || print_error "'$1' required but not installed. Install it and run again"
}

print_cluster_info() {
    cluster_name=$1
    aws_profile=$2
    aws_region=$3

    echo "CLUSTER INFO"
    echo "Cluster Name:   $cluster_name"
    echo "AWS Region:     $aws_region"
    echo "AWS Profile:    $aws_profile"
}

launch() {
    inventory_file=$1
    cluster_name=$2
    aws_profile=$3
    aws_region=$4

    print_cluster_info $cluster_name $aws_profile $aws_region
    echo ""
    
    if ! ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $inventory_file ansible/provision.yml; then
        echo "Provision failed. Try to run it separately"
        exit 1
    fi
    deploy $inventory_file
}

deploy() {
    inventory_file=$1
    cluster_name=$2
    echo "Deploying (or redeploying) $cluster_name"
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $inventory_file ansible/deploy.yml
}

sagactx() {
    inventory_file=$1
    cluster_name=$2
    echo "Configuring sagacli and spcd to connect to $cluster_name"
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $inventory_file ansible/update-cliconfig.yml
}

delete() {
    inventory_file=$1
    cluster_name=$2
    aws_profile=$3
    aws_region=$4

    print_cluster_info $cluster_name $aws_profile $aws_region
    echo ""
    # shellcheck disable=SC2162
    read -p "Are you sure you want to delete $cluster_name? (y/n) " confirmation
    if [[ $confirmation != "y" || $confirmation == "Y" ]]; then
        echo "Aborting..."
        exit 0
    fi
    echo ""

    if ! ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $inventory_file ansible/delete.yml; then
        echo "Delete fail. Try to run it separately"
        exit 1
    fi
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $inventory_file ansible/decommission.yml
}

kubeconfig() {
    inventory_file=$1
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $inventory_file ansible/update-kubeconfig.yml
}

updateTemplates() {
    inventory_file=$1
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $inventory_file ansible/playbooks/controller/update-templates.yml
}

localSetup() {
    ansible-galaxy install -r ansible/ansible_requirements.yml
}

command=$1

# No args commands
if [ $command == "help" ]; then
    print_usage $0
fi
if [ $command == "localSetup" ]; then
    localSetup
    exit 0
fi

if [ $# -ne 2 ]; then
    print_usage $0
fi

allowed_commands=("launch" "delete" "relaunch" "deploy" "sagactx" "kubeconfig" "updateTemplates" "help")
# shellcheck disable=SC2076
if [[ ! " ${allowed_commands[*]} " =~ " $command " ]]; then
    echo "'$command' is not a valid command"
    echo "Supported commands: " "${allowed_commands[@]}"
    exit 1
fi

inventory_file=$2
if [  ! -e "$inventory_file" ]; then
    echo "$inventory_file does not exist."
    echo "Provide a valid inventory file path. E.g.: ansible/testnet/sp1.yml"
    exit 1
fi

required_commands=( yq ansible-playbook ssh kubectl aws )
for required_command in "${required_commands[@]}"
do
  assert_command_installed $required_command
done

cluster_name=$(cat $inventory_file | yq -r '.eks_clusters.hosts | keys | .[0]')
aws_profile=$(cat $inventory_file | yq -r '.eks_clusters.vars.aws_profile')
aws_region=$(cat $inventory_file | yq -r '.eks_clusters.hosts.'$cluster_name'.aws_region')



if ! aws configure list-profiles | grep $aws_profile > /dev/null; then
    echo "AWS profile not configured. Add $aws_profile to ~/.aws/credentials"
    exit 1
fi

export AWS_PROFILE=$aws_profile

current_aws_profile=$(aws configure list | grep "^   profile" | sed 's/^[ ]*profile[ ]*//' | sed 's/ .*//')

if [ $current_aws_profile != $aws_profile ]; then
    echo "Current aws profile is $current_aws_profile. Set it to $aws_profile running 'export AWS_PROFILE=$aws_profile'"
    exit 1
fi

case "$command" in
    "launch")
        launch $inventory_file $cluster_name $aws_profile $aws_region
        ;;
    "delete")
        delete $inventory_file $cluster_name $aws_profile $aws_region
        ;;
    "relaunch")
        delete $inventory_file $cluster_name $aws_profile $aws_region
        launch $inventory_file $cluster_name $aws_profile $aws_region
        ;;
    "deploy")
        deploy $inventory_file $cluster_name
        ;;
    "sagactx")
        sagactx $inventory_file $cluster_name
        ;;
    "kubeconfig")
        kubeconfig $inventory_file
        ;;
    "updateTemplates")
        updateTemplates $inventory_file
        ;;
    "localSetup")
        localSetup
        ;;
    "help")
        print_usage $0
        ;;
    *)
        echo "'$command' is not a valid command"
        echo "Supported commands: " "${allowed_commands[@]}"
        exit 1
        ;;
esac

# echo "Launching $cluster_name by $aws_profile in $aws_region"
# echo $cluster_name
