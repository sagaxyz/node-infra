# Run a SAGA validator cluster

## Prerequisites
- An AWS account.
- An AWS IAM User with privileges: `ec2:*`, `eks:*`, `iam:*`, `cloudformation:*`, `acm:*`, `autoscaling:Describe*`, `route53:*`, `elasticloadbalancing:DescribeTargetGroups`. All can be restricted to the region the cluster is delivered. The route53 permission is only required on the domain used to expose the SPC validator.
- `aws-cli` installed on the machine that is provisioning the cluster
- The IAM user credentials should be stored locally in `~/.aws/credentials`
- A public subdomain delegated to route53. This will be used to expose SPC to other validators. E.g.: [How to delegate cloudflare subdomain](link)
- Ansible installed
- pip3 and python3 installed

**NOTE:** The user is only used for the provisioning. It is possible to deactivate the user after deploying the cluster for the first time, unless infra changes are required. Follow [this guide](link) to create a specific user/role to access the cluster.

## Gentx
We are coordinating the gentx ceremony offline. You will receive an unsigned genesis file and will need to generate a gentx and share it with us. Execute these commands in a safe environment and make sure to save the credentials that you will use later for your validator (mnemonic and `node_key.json`).

```bash
scpd add key <validator_key_name>
```
Make sure you are saving the generated mnemonic and `~/.spc/config/node_key.json`. You can alternatively use an existing mnemonic (--recover) or a ledger (--ledger). The problem with the latter is that you will have to know the mnemonic and provide it to the cluster. We are working on a safer solution to avoid this.

Share the address created with us (spcd keys show <validator_key_name>). Once collected all the addresses we will share the unsigned genesis file with you.

Once we share the genesis file with you. You can generate the gentx.
```
spcd init --chain-id=spc-devnet-1 --recover --default-denom upsaga <your_moniker>
cp <provided_genesis_file> ~/.spc/config/genesis.json
spcd gentx <validator_key_name> "1500000stake" --chain-id spc-devnet-1 --ip spc.<your_validator_moniker>.spc-devnet-1.<route53_zone>
```
**The public address has to be from a subdomain you control on Route53 (see prerequisites #5).** Make sure you use the same moniker and route53_zone in the inventory below.

## Inventory file
Copy the devnet inventory sample to your repo (`cp sample/devnet.sample.yml <your_inventory_file.yml>`). Now, you can edit the inventory file, there are 10 variables marked with “CHANGE IT”. See the following two sections for specific instructions on each one of them.

### Variables
- `aws_region`: the AWS region where the cluster runs.
- `aws_profile`: the profile name of the deployer IAM User with the required privileges. This is used to provision the cluster. It has to be the same saved in `~/.aws/credentials`.
- `moniker`: your validator moniker.
- `route53_zone`: the (sub)domain controlled by route53. The deploy playbook will create the record to expose spc to other validators (`spc.{{ route53_zone }}`).

The default inventory hostname is `eks-cluster-name`. This is going to be the name of your EKS cluster. You can override it with your desired EKS cluster name. It can be your moniker if you don't have an already running cluster on AWS, in the same region.

### Secrets

Secrets should be provided as variables. They can live in a single inventory file with the other variables (in case use ansible-vault encryption at least). To increase security, they can be in a separate inventory file offline. Moving soon from embedded signatures to remote key management and public docker registry will make this part less critical.

- `validator_mnemonic`:  your validator 24 words mnemonic.
- `spc_node_key`: base64 encoded `node_key.json` you used to sign the gentx (`cat ~/.spc/config/node_key.json | base64 | pbcopy`)
- `vault_grafana_admin_password`: web ui grafana password to check metrics. By default, we are not exposing grafana, which can be reached by port-forwarding. As an alternative, you can set `publicly_expose_grafana: true`.
- [optional] `alertmanager.cluster_alerts_slack_url`: slack webhook url. It's optional. If set, AlertManager will post alerts to the channel.

### Additional services

We recommend validators to only support validation and leave additional services to service providers. Although, it is possible to deploy additional services with the same deploy scripts. Specifically:

- Publicly exposed RPC and gRPC
- Publicly exposed rest API
- Publicly exposed explorers
- EFK stack
- SSC Snapshots
- SPC Snapshots

## Provision
This step provisions an EKS cluster with Karpenter autoscaler, oidc provider and EBS CSI driver. As a first step checkout the devnet branch of the infrastructure repo.

This is the command to run to provision your cluster from the ansible directory:
```
cd ansible
ansible-playbook -i your_inventory_file.yml [-i your_secrets_file.yml] provision.yml
```
It should ideally run once, unless requested. But it is idempotent so it can be run multiple times to fix possible inconsistencies that might arise.

## Deploying
The deploy playbook is responsible for deploying the applications and metrics stack. It will also add the DNS entries to expose SPC.
```
./setup.sh
source venv/bin/activate
cd ansible
ansible-playbook -i your_inventory_file.yml [-i your_secrets_file.yml] deploy.yml
```

Also the deploy playbook is idempotent and can be run many times. It can be run, for example, to upgrade any application.

After a sufficient number of validators have completed this step, you should see from the logs that spc is producing blocks (`kubectl get pods -n sagasrv-spc`).

## Cluster access
The deploy script will create a kubeconfig file: `~/.kube/cluster_name`. It is possible to access the cluster passing `--kubeconfig ~/.kube/cluster_name` to any kubectl command. To setup the kubeconfig without deploying:
```
ansible-playbook -i your_inventory_file.yml update-kubeconfig.yml
```
This playbook will create`~/.kube/cluster_name` and will add a context with the cluster name under the main kubectl config. This is compatible with kubectx for context switching.

To allow other user to access the cluster without leaking high privilege permissions, it is possible to create a custom user with `eks:DescribeCluster` permission on the cluster. That would be enough to run
```
aws eks update-kubeconfig --name <your_cluster_name>
```
It is possible, of course, to implement a more granular cluster access using kubernetes native RBAC.

### Metrics
The playbook is deploying the kube prometheus stack with some additional application level dashboards. In particular there are dynamic dashboards tracking chainlet metrics as far as they are added. You can access the grafana UI port forwarding the related service:
```
kubectl port-forward service/grafana 3000:3000 -n sagasrv-metrics
```
As an alternative it is possible to expose grafana publicly by setting `publicly_expose_grafana: true`. The username is `admin` and the password is the one you set in the secrets.

NOTE: this is a stateless application with no persistence. To deploy/modify a dashboard, you will need to do it via ConfigMap. Check files under `ansible/playbooks/metrics/prometheus-operator/manifests/dashboards`.

### Alerts
Alerts are deployed via PrometheusRule (a Kubernetes CRD deployed with the kube prometheus stack). There are a set of alerts that come with the stack plus a set of custom alerts that are application specific. You can find them under `ansible/playbooks/metrics/prometheus-operator/manifests/alertmanager/rules`. The default configuration routes all the alerts to a slack channel specified in the inventory as webhook. It is possible to change that and use a more refined alert routing (e.g.: pager duty for the critical alerts), by modifying `ansible/playbooks/metrics/prometheus-operator/manifests/alertmanager/alertmanager-config.yaml`.
