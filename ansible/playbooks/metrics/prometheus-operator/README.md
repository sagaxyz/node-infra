# Cassiopeia Prometheus Operator

## Introduction

This is the Cassiopeia Prometheus Operator sub-project, which gathers the required scripts and configurations for generating the prometheus operator deployment stack.
The deployment files have not been generated once and versioned together with the project because the configuration could be quite volatile.

## Installing

The content of this project consists of a set of [jsonnet](http://jsonnet.org/) files making up a library to be consumed.

Install this library in your own project with [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler#install) (the jsonnet package manager):

```shell
$ jb install github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus@release-0.12 # Creates `vendor/` & `jsonnetfile.lock.json`, and fills in `jsonnetfile.json`
```

> `jb` can be installed with `go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest`

You may need also `gojsontoyaml`, used for the k8s yaml file generation. 
> `gojsontoyaml` can be installed with `go install -a github.com/brancz/gojsontoyaml@latest`

In order to update the kube-prometheus dependency, simply use the jsonnet-bundler update functionality:

```shell
$ jb update
```

## Generating

Now that we have all dependencies, we are ready to generate the kubernetes deployments file.
A `build.sh` script is available to do that.

```shell
$ ./build.sh -a
```

The main file used for compiling the outputs is `cassiopeia.jsonnet`, where all the cassio related stuff has been configured.
There are a few flags availabe in the script for customizing the generated documents.

- `-a`: the compiled documents are meant to be used by Ansible later
- `-p`: the Grafana admin password (ignored if `-a`)
- `-h`: the cluster base url (ignored if `-a`)

Too see the script usage just execute the script without arguments: 
```bash
$ ./build.sh
```

After a successful execution you should see a directory `manifests` with tons of k8s yaml file. If so, then you're ready to proceed.

### Updating the configuration

It is very important to understand that we will have to regenerate the manifests every time we modify something in the project. After doing so it is also required to push to the versioning system the updated manifests. This way ansible users do not depend on the jsonnet project dependencies for launching the provisioning/deploying of the infra.

## Configuring

All the generated files can be customized without doing it directly inside the generated manifests directory.
That it's a mistake because after another build execution, every customizations is lost.
What you want to do is to modify the `cassiopeia.jsonnet` file for introducing new behaviours or customizing something.
Furthermore, a file called `prometheus-additional.yaml` has been introduced for extending the scraping behaviour of prometheus isolating all
the new stuff inside a specific file.

### Dashboards

If you want to add a new Grafana dashboard you can do that as well.
For doing that, you have to create a `json` file containing the dashboard configuration (you can export that from the Grafana UI). Once you've done that, you have just to customize the dashboard configs in `cassiopeia.jsonnet`, duplicating the already existing lines for including a chainlet dashboard.

Obviously, in order to edit a Grafana dashboard, it's required to modify the dashboard json file.

### Alerts

We can add new alerts as well. For doing so, you have to modify the already existing file `custom-alerts.json`, including or modifying the alerts as required by your use case.
You can gather the alerts JSON state as well from Grafana, invoking the API endpoint as shown below:

```bash
$ curl --silent -H "Authorization: Bearer <service_account_token>" https://grafana.endpoint.xyz/api/ruler/grafana/api/v1/rules
```

As you can see, it is required to obtain an authorization token before being able to invoke the endpoint.<br/>
<u><b>Another viable way is to login through the Grafana UI and then call the endpoint using the same browser.</b></u>

## Apply the kube-prometheus stack

### Manual

The previous generation step has created a bunch of manifest files in the manifest/ folder.
Now simply use `kubectl` to install Prometheus and Grafana as per your configuration:

```shell
# Update the namespace and CRDs, and then wait for them to be available before creating the remaining resources
$ kubectl create -f manifests/setup
$ kubectl create -f manifests/
```

Check the `sagasrv-metrics` namespace (or the namespace you have specific in `namespace: `) and make sure the pods are running. Prometheus and Grafana should be up and running soon.

### Ansible

If in your inventory file the `metrics_enabled` flag is `true` for a specific host, then the metrics stack is going to be deployed with the `deploy.yaml` playbook file to that host.
It is usually required to deploy the metrics stack among all the hosts configured in the cluster and not only in a specific one, but this can change giving the use case.

## Access to Grafana and Prometheus dashboard

If the apps are not exposed to the internet, you can port-forward with kubectl for accessing them:

```bash
# access to graphana
$ kubectl --namespace sagasrv-metrics port-forward svc/grafana 3000

# access to prometheus
$ kubectl --namespace sagasrv-metrics port-forward svc/prometheus-k8s 9090
```