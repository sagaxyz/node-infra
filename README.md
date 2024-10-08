# Run a SAGA validator cluster

## Prerequisites
- An AWS account.
- An AWS IAM User with privileges: `ec2:*`, `eks:*`, `iam:*`, `cloudformation:*`, `acm:*`, `autoscaling:Describe*`, `route53:*`, `elasticloadbalancing:DescribeTargetGroups`. All can be restricted to the region the cluster is delivered.
- `aws-cli` installed on the machine that is provisioning the cluster
- The IAM user credentials should be stored locally in `~/.aws/credentials`
- A public subdomain delegated to route53. This will be used to expose SPC to other validators. E.g.: [How to delegate cloudflare subdomain](https://developers.cloudflare.com/dns/manage-dns-records/how-to/subdomains-outside-cloudflare/)
- Ansible installed
- pip3 and python3 installed
- Share the AWS account id with Saga, in order to gain programmatic access to genesis files
- [mainnet only] Request quota increase on AWS for `Inbound or outbound rules per security group` to `500`
- Hosted zone on route53 we can use to expose SPC. We suggest a saga.* subdomain

*⚠️ If deploying mainning make sure AWS rules per security group are increased to 500. This might take days and will break the mainnet deployment ⚠️*

**NOTE:** The user is only used for the provisioning. It is possible to deactivate the user after deploying the cluster for the first time, unless infra changes are required. Follow [this guide](link) to create a specific user/role to access the cluster.

## Inventory file
Copy the testnet|mainnet inventory sample to your repo (`cp sample/<testnet|mainnet>.sample.yml <your_inventory_file.yml>`). Now, you can edit the inventory file, there are 8 variables marked with “CHANGE IT”. See the following two sections for specific instructions on each one of them.

### Variables
- `aws_region`: the AWS region where the cluster runs.
- `aws_profile`: the profile name of the deployer IAM User with the required privileges. This is used to provision the cluster. It has to be the same saved in `~/.aws/credentials`.
- `moniker`: your validator moniker.
- `route53_zone`: hosted zone in Route53 you will use to expose SPC p2p. Route53 must be autoritative.

The default inventory hostname is `eks-cluster-name`. This is going to be the name of your EKS cluster. You can override it with your desired EKS cluster name. It can be your moniker if you don't have an already running cluster on AWS, in the same region. NOTE: this is a yaml key.

### Secrets

Secrets should be provided as variables. They can live in a single inventory file with the other variables (in case use ansible-vault encryption at least). To increase security, they can be in a separate inventory file offline. Moving soon from embedded signatures to remote key management and public docker registry will make this part less critical.

- `validator_mnemonic`:  your validator 24 words mnemonic.
- `vault_grafana_admin_password`: web ui grafana password to check metrics. By default, we are not exposing grafana, which can be reached by port-forwarding. As an alternative, you can set `publicly_expose_grafana: true`.
- `keychain_password`: password used by the chainlet validator to locally encrypt the keys
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
This step provisions an EKS cluster with Karpenter autoscaler, oidc provider and EBS CSI driver. As a first step checkout the `release/mainnet` branch of the node-infra repo.

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

After SPC is live, your validator should be able to join the network. Check the logs of the SPC pod for info (`kubectl get pods -n sagasrv-spc`).

## Joining as validator
In order to join as validator make sure `validator_provider: 1`, that the validator address generated from your mnemonic has the necessary stake to join (send by Saga). The creation of the validator and join of the network will happen automatically if the prerequisites are satisfied as part of the start script of SPC and chainlets.

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
