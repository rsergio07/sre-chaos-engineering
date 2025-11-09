# Phase 1: Environment Setup

## Table of Contents

- [Overview](#overview)
- [Learning Objectives](#learning-objectives)
- [Step 1: Verify Cluster Resources](#step-1-verify-cluster-resources)
- [Step 2: Enable Kubernetes Dashboard](#step-2-enable-kubernetes-dashboard)
- [Step 3: Deploy Chaos Target Application](#step-3-deploy-chaos-target-application)
- [Step 4: Install LitmusChaos Operator](#step-4-install-litmuschaos-operator)

---

## Overview

This phase establishes the complete infrastructure needed for both manual and automated chaos engineering. You will deploy a three-replica nginx application that serves as the chaos target, enable the Kubernetes Dashboard for manual observability, and install the LitmusChaos platform for automated resilience testing.

The setup follows a deliberate sequence: first verify your cluster has adequate resources, then enable native Kubernetes observability tools, deploy the application you'll test, and finally install the chaos engineering platform. This layered approach ensures each component is healthy before proceeding to the next.

**Expected Time:** 15-20 minutes

**What You'll Install:**
- Kubernetes Dashboard and Metrics Server (native observability)
- Chaos target application (3 nginx replicas with health checks)
- LitmusChaos Operator (chaos execution engine)
- LitmusChaos Portal (web UI for experiment design)

---

## Learning Objectives

By completing this phase, you will:

1. Verify that your Kubernetes cluster has adequate CPU and memory resources to run chaos experiments without resource contention.

2. Enable and access the Kubernetes Dashboard to provide real-time visual monitoring during manual chaos scenarios.

3. Deploy a production-ready application with multiple replicas, resource limits, and health checks that will serve as the chaos target.

4. Install the LitmusChaos operator and understand how it uses Custom Resource Definitions to execute chaos experiments declaratively.

5. Deploy the LitmusChaos Portal web interface and access it to prepare for automated chaos workflow design.

---

## Step 1: Verify Cluster Resources

Before installing any components, confirm your Minikube cluster has adequate resources. Insufficient CPU or memory will cause pods to remain pending or crash unexpectedly during chaos experiments.

### Check Current Cluster Status

```bash
# Verify cluster is running
kubectl cluster-info

# Check node status
kubectl get nodes
```

**Expected output:**
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   5m    v1.33.1
```

The node must show STATUS "Ready". If it shows "NotReady", your cluster has a critical issue.

### Verify Resource Allocation

```bash
# Check node capacity
kubectl describe node minikube | grep -A 5 "Allocatable"
```

**Expected output:**
```
Allocatable:
  cpu:                6
  memory:             12582912Ki
  pods:               110
```

**Minimum required resources:**
- **CPU:** 6 cores
- **Memory:** 12GB (12582912Ki)

### If Resources Are Insufficient

If your node shows less than 6 CPUs or 12GB memory, you need to recreate Minikube with proper allocations:

```bash
# Stop current cluster
minikube stop

# Delete existing cluster
minikube delete

# Recreate with adequate resources
minikube start \
  --driver=docker \
  --cpus=6 \
  --memory=12288 \
  --disk-size=40g

# Verify new allocation
kubectl describe node minikube | grep -A 5 "Allocatable"
```

### Check System Pods Are Healthy

```bash
# All kube-system pods should be Running
kubectl get pods -n kube-system
```

**Expected output:**
```
NAME                               READY   STATUS    RESTARTS   AGE
coredns-xxxxx                      1/1     Running   0          5m
etcd-minikube                      1/1     Running   0          5m
kube-apiserver-minikube            1/1     Running   0          5m
kube-controller-manager-minikube   1/1     Running   0          5m
kube-proxy-xxxxx                   1/1     Running   0          5m
kube-scheduler-minikube            1/1     Running   0          5m
storage-provisioner                1/1     Running   0          5m
```

All pods must show STATUS "Running" and READY "1/1".

---

## Step 2: Enable Kubernetes Dashboard

The Kubernetes Dashboard provides visual monitoring of pod states, events, and resource consumption. You'll use it extensively during Track 1 to observe chaos impact in real time.

### Enable Dashboard Addon

```bash
# Enable dashboard
minikube addons enable dashboard

# Enable metrics-server for resource monitoring
minikube addons enable metrics-server
```

**Expected output:**
```
💡  dashboard is an addon maintained by Kubernetes. For any concerns contact minikube on GitHub.
You can view the list of minikube maintainers at: https://github.com/kubernetes/minikube/blob/master/OWNERS
    ▪ Using image docker.io/kubernetesui/dashboard:v2.7.0
    ▪ Using image docker.io/kubernetesui/metrics-scraper:v1.0.8
💡  Some dashboard features require the metrics-server addon. To enable all features please run:

	minikube addons enable metrics-server	

🌟  The 'dashboard' addon is enabled
```

### Verify Dashboard Pods

```bash
# Wait for dashboard pods to be ready
kubectl wait --for=condition=Ready pods --all -n kubernetes-dashboard --timeout=120s

# Check pod status
kubectl get pods -n kubernetes-dashboard
```

**Expected output:**
```
NAME                                         READY   STATUS    RESTARTS   AGE
dashboard-metrics-scraper-xxxxx              1/1     Running   0          1m
kubernetes-dashboard-xxxxx                   1/1     Running   0          1m
```

### Access Dashboard

```bash
# Open dashboard in browser (runs in foreground)
minikube dashboard
```

This command automatically opens your default browser to the Dashboard URL. The dashboard provides:
- Real-time pod status visualization
- Event logs for debugging
- Resource usage graphs
- Node and namespace views

**Keep this terminal open.** Open a new terminal for subsequent commands.

**Alternative access method** (if automatic browser opening fails):

```bash
# In Terminal 1: Start proxy
kubectl proxy --address='0.0.0.0' --port=8001
```

Then access manually at:
```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
```

---

## Step 3: Deploy Chaos Target Application

Now deploy the application that will serve as your chaos testing target. This application uses production-ready patterns including multiple replicas, resource limits, health checks, and custom configuration.

### Verify Manifest Files Exist

```bash
# Check that manifests are present
ls -la manifests/stable/
ls -la manifests/unstable/
```

**Expected output:**
```
manifests/stable/:
configmap.yaml
deployment.yaml
service.yaml

manifests/unstable/:
configmap.yaml
deployment.yaml
service.yaml
```

### Inspect Stable Deployment Configuration

```bash
# View the stable deployment manifest
cat manifests/stable/deployment.yaml
```

**Key configuration elements to note:**

- **Replicas:** 3 pods for high availability
- **Image:** `nginx:1.21-alpine` (stable, working image)
- **Resource limits:** CPU 100m, Memory 128Mi (prevents resource exhaustion)
- **Liveness probe:** HTTP GET on port 80 every 10 seconds
- **Readiness probe:** HTTP GET on port 80 every 5 seconds
- **Labels:** `app: chaos-target-app` and `version: stable`

### Deploy Stable Version

```bash
# Apply all stable manifests
kubectl apply -f manifests/stable/

# Wait for deployment to complete
kubectl rollout status deployment/chaos-target-app --timeout=120s
```

**Expected output:**
```
configmap/app-content created
deployment.apps/chaos-target-app created
service/chaos-target-service created
Waiting for deployment "chaos-target-app" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "chaos-target-app" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "chaos-target-app" rollout to finish: 2 of 3 updated replicas are available...
deployment "chaos-target-app" successfully rolled out
```

### Verify Application Pods

```bash
# Check pod status
kubectl get pods -l app=chaos-target-app

# Verify all pods are ready
kubectl get pods -l app=chaos-target-app -o wide
```

**Expected output:**
```
NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE
chaos-target-app-xxxxx-xxxxx        1/1     Running   0          1m    10.244.0.4   minikube
chaos-target-app-xxxxx-xxxxx        1/1     Running   0          1m    10.244.0.5   minikube
chaos-target-app-xxxxx-xxxxx        1/1     Running   0          1m    10.244.0.6   minikube
```

All three pods must show:
- READY: `1/1`
- STATUS: `Running`
- RESTARTS: `0`

### Verify Service Endpoints

```bash
# Check service was created
kubectl get service chaos-target-service

# Verify service has endpoints pointing to pods
kubectl get endpoints chaos-target-service
```

**Expected output:**
```
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
chaos-target-service   ClusterIP   10.96.123.456   <none>        80/TCP    1m

NAME                   ENDPOINTS                                      AGE
chaos-target-service   10.244.0.4:80,10.244.0.5:80,10.244.0.6:80     1m
```

The endpoints list should contain three IP addresses matching your pod IPs.

### Test Application Accessibility

```bash
# Port-forward to service (runs in background)
kubectl port-forward svc/chaos-target-service 8080:80 --address 0.0.0.0 &
PORT_FORWARD_PID=$!
echo "Port-forward PID: $PORT_FORWARD_PID"

# Wait for port-forward to initialize
sleep 3

# Test application responds
curl -s http://localhost:8080 | grep -o "<title>.*</title>"
```

**Expected output:**
```
<title>Chaos Engineering Target</title>
```

The application should return HTML content. You can also test in a browser at `http://localhost:8080`.

**Keep port-forward running** for later testing. To stop it later:
```bash
kill $PORT_FORWARD_PID
```

---

## Step 4: Install LitmusChaos Operator

The LitmusChaos operator is the core chaos execution engine. It watches for ChaosEngine custom resources and executes the chaos experiments they define.

### Create Litmus Namespace

```bash
# Create dedicated namespace for chaos infrastructure
kubectl create namespace litmus
```

**Expected output:**
```
namespace/litmus created
```

### Install Operator Manifests

```bash
# Apply LitmusChaos operator
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml -n litmus
```

**Expected output:**
```
customresourcedefinition.apiextensions.k8s.io/chaosengines.litmuschaos.io created
customresourcedefinition.apiextensions.k8s.io/chaosexperiments.litmuschaos.io created
customresourcedefinition.apiextensions.k8s.io/chaosresults.litmuschaos.io created
serviceaccount/litmus-admin created
clusterrole.rbac.authorization.k8s.io/litmus-admin created
clusterrolebinding.rbac.authorization.k8s.io/litmus-admin created
deployment.apps/chaos-operator-ce created
service/chaos-operator-ce-metrics created
```

This creates:
- **CRDs:** ChaosEngine, ChaosExperiment, ChaosResult
- **RBAC:** ServiceAccount, ClusterRole, ClusterRoleBinding
- **Operator deployment:** chaos-operator-ce

### Wait for Operator to Be Ready

```bash
# Wait up to 5 minutes for operator pod to be ready
kubectl wait --for=condition=Ready pods --all -n litmus --timeout=300s
```

**Expected output:**
```
pod/chaos-operator-ce-xxxxx-xxxxx condition met
```

### Verify Operator Installation

```bash
# Check operator pod status
kubectl get pods -n litmus

# Check CRDs were created
kubectl get crds | grep chaos
```

**Expected output:**
```
NAME                           READY   STATUS    RESTARTS   AGE
chaos-operator-ce-xxxxx-xxxxx  1/1     Running   0          2m

chaosengines.litmuschaos.io         2024-11-08T20:00:00Z
chaosexperiments.litmuschaos.io     2024-11-08T20:00:00Z
chaosresults.litmuschaos.io         2024-11-08T20:00:00Z
```

The operator pod must be Running and three chaos-related CRDs should exist.

### Check All Pods Across Namespaces

```bash
# View complete cluster state
kubectl get pods -A
```

**Expected output:**
```
NAMESPACE              NAME                                     READY   STATUS    RESTARTS   AGE
default                chaos-target-app-xxxxx-xxxxx             1/1     Running   0          5m
default                chaos-target-app-xxxxx-xxxxx             1/1     Running   0          5m
default                chaos-target-app-xxxxx-xxxxx             1/1     Running   0          5m
kube-system            coredns-xxxxx                            1/1     Running   0          15m
kube-system            etcd-minikube                            1/1     Running   0          15m
kube-system            kube-apiserver-minikube                  1/1     Running   0          15m
kube-system            kube-controller-manager-minikube         1/1     Running   0          15m
kube-system            kube-proxy-xxxxx                         1/1     Running   0          15m
kube-system            kube-scheduler-minikube                  1/1     Running   0          15m
kube-system            storage-provisioner                      1/1     Running   0          15m
kubernetes-dashboard   dashboard-metrics-scraper-xxxxx          1/1     Running   0          8m
kubernetes-dashboard   kubernetes-dashboard-xxxxx               1/1     Running   0          8m
litmus                 chaos-operator-ce-xxxxx-xxxxx            1/1     Running   0          6m
```

---

## Next Steps

With all infrastructure deployed and verified, you're ready to begin chaos engineering exercises.

**You can now proceed to:**

[Track 1: Emergency Rollback Drill (Manual Response)](track-1-manual-response.md)

This track simulates production incident response using manual chaos injection and kubectl-based recovery procedures.

**Or jump directly to:**

[Track 2: Scheduled Resilience Testing (Automated Chaos)](track-2-automated-chaos.md)

This track demonstrates automated chaos workflows using the LitmusChaos Portal.

**Recommended:** Complete Track 1 first to establish baseline MTTR measurements before comparing with automated approaches in Track 2.