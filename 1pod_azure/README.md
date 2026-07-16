# One-Pod Azure Kubernetes Hello World Lab

This project creates a small Azure Kubernetes Service learning environment:

- one Azure resource group;
- one AKS cluster using the Free control-plane tier;
- one `Standard_D4as_v5` worker node (the low-cost default for this lab);
- one NGINX Hello World Pod;
- one public Azure Load Balancer Service;
- startup, readiness, and liveness probes;
- an automated verification of the one-Pod invariant, landing page, health
  endpoint, and HTTP ping response.

This project creates **billable Azure resources**, including the virtual
machine, managed disk, public IP, and load balancer resources. Destroy the lab
when you finish.

## Architecture

```text
Browser or curl
      |
      v
Azure public Load Balancer
      |
      v
Kubernetes Service
      |
      v
One NGINX Hello World Pod
```

## Prerequisites

Install the Azure CLI, Terraform, and kubectl. On macOS with Homebrew:

```bash
brew install azure-cli terraform kubectl
```

Confirm that your Azure subscription has at least four general-purpose vCPUs
available in the selected region. The default region is `westus3` and the
default node is `Standard_D4as_v5`. AKS system node pools do not support
B-series VMs.

## Sign in and select the subscription

```bash
az login
az account list --output table
az account set --subscription YOUR_SUBSCRIPTION_ID
az account show --output table
```

The setup script reads the active subscription ID from `az account show` and
passes it to Terraform. You can alternatively set it explicitly:

```bash
export TF_VAR_subscription_id=YOUR_SUBSCRIPTION_ID
```

## Create and verify the lab

```bash
cd /Users/dc/terraform/1pod_azure
./scripts/setup.sh
```

AKS creation normally takes several minutes. The setup script:

1. validates the required local commands and Azure login;
2. creates the resource group and one-node AKS cluster;
3. writes an isolated `.kubeconfig` inside this directory;
4. deploys exactly one NGINX Hello World Pod;
5. exposes it with an Azure Load Balancer;
6. verifies one desired, ready, and running Pod;
7. sends HTTP requests to `/`, `/healthz`, and `/ping` and validates the
   responses.

The final output includes the public URL:

```text
Verification passed.
  Desired web Pods: 1
  Ready web Pods:   1
  Running web Pods: 1
  Hello World URL:  http://PUBLIC_IP
  HTTP ping:        http://PUBLIC_IP/ping -> pong
```

Test the public server directly:

```bash
PUBLIC_IP="$(terraform output -raw hello_world_public_ip)"
curl --noproxy '*' "http://$PUBLIC_IP/ping"
curl --noproxy '*' "http://$PUBLIC_IP/healthz"
curl --noproxy '*' "http://$PUBLIC_IP/"
```

The `/ping` endpoint is an HTTP reachability test and returns `pong`. The
operating-system `ping` command uses ICMP; an AKS TCP LoadBalancer Service does
not expose an ICMP echo endpoint.

## Inspect the deployment

```bash
export KUBECONFIG=/Users/dc/terraform/1pod_azure/.kubeconfig

kubectl get nodes
kubectl -n hello-world get deployment,pods,service -o wide
kubectl -n hello-world describe pod -l app.kubernetes.io/name=hello-world
kubectl -n hello-world logs deployment/hello-world
```

Run verification again at any time:

```bash
./scripts/verify.sh
```

## Configuration overrides

Use environment variables to change common settings:

```bash
export TF_VAR_location=westus3
export TF_VAR_node_vm_size=Standard_D4as_v5
export TF_VAR_resource_group_name=one-pod-azure-lab-rg
export TF_VAR_cluster_name=one-pod-azure-lab
./scripts/setup.sh
```

If `Standard_D4as_v5` is unavailable for your subscription or region, select
an AKS-supported non-B-series system-pool size with at least four vCPUs and
four GiB of memory for which you have quota. The setup script checks the SKU
before creating billable resources.

## Destroy the lab

Keep the same Azure subscription selected, then run:

```bash
cd /Users/dc/terraform/1pod_azure
./scripts/destroy.sh
```

Confirm afterward:

```bash
az group exists --name one-pod-azure-lab-rg
```

The expected result is `false`.
