# Local kind HPA Scale Test

This project creates a single-node kind cluster, builds a CPU-intensive Go web
server, and deploys it behind a ClusterIP Service. Metrics Server supplies CPU data to an
`autoscaling/v2` HPA that can scale the Deployment from one Pod to two Pods.

The load generator is a k6 Kubernetes Job. Traffic stays inside the cluster:

```text
k6 Job -> web ClusterIP Service -> Ready web Pods
                         CPU metrics -> Metrics Server -> HPA
```

## Start the lab

Start Docker Desktop, then run:

```bash
cd /Users/dc/terraform/2pods
./scripts/setup.sh
```

The setup script creates the kind cluster, installs Metrics Server, applies the
Terraform configuration, and waits for the web Deployment.

## Run and verify the autoscaling cycle

```bash
./scripts/run-hpa-test.sh
```

The k6 Job performs five stages:

1. one request/second baseline;
2. ramp to 25 requests/second;
3. hold high load for two minutes;
4. ramp down to one request/second;
5. remain at low load long enough for HPA scale-down.

The verification script samples Kubernetes every five seconds and fails unless
it observes two Ready web Pods followed by a return to one Ready Pod. Each run
writes a TSV timeline under `results/`.

Useful commands while the test runs:

```bash
KUBECONFIG=.kubeconfig kubectl -n web-autoscaling get hpa web --watch
```

```bash
KUBECONFIG=.kubeconfig kubectl -n web-autoscaling get pods --watch
```

```bash
KUBECONFIG=.kubeconfig kubectl -n web-autoscaling describe hpa web
```

## Destroy

```bash
./scripts/destroy.sh
```
