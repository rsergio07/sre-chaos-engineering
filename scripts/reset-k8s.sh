#!/bin/bash
echo "=== 🛑 Starting Kubernetes Cluster Cleanup ==="

# 1. Delete existing Minikube cluster
if minikube status &> /dev/null; then
    echo "  -> Deleting existing minikube cluster..."
    minikube delete
else
    echo "  -> No active minikube cluster found."
fi

# 2. Restart Colima with adequate resources
echo ""
echo "=== 🔧 Configuring Colima VM Resources ==="
echo "  -> Stopping Colima (if running)..."
colima stop 2>/dev/null || true

echo "  -> Starting Colima with:"
echo "     - CPUs: 8"
echo "     - Memory: 16GB"
echo "     - Disk: 60GB"
echo ""

colima start --cpu 8 --memory 16 --disk 60 --vm-type qemu

if [ $? -ne 0 ]; then
    echo "=== ❌ Error: Colima failed to start ==="
    exit 1
fi

# 3. Wait for Docker daemon to be ready
echo "  -> Waiting for Docker daemon to initialize..."
sleep 10

# 4. Verify Docker is accessible
if ! docker ps &> /dev/null; then
    echo "=== ❌ Error: Docker daemon not accessible ==="
    exit 1
fi

echo ""
echo "=== ✨ Creating Kubernetes Cluster for Chaos Engineering Lab ==="
echo "  -> CPUs: 6 (from Colima's 8)"
echo "  -> Memory: 12GB (from Colima's 16GB)"
echo "  -> Disk: 40GB (from Colima's 60GB)"
echo ""

# 5. Start Minikube with explicit resource allocation
minikube start \
  --driver=docker \
  --embed-certs \
  --cpus=6 \
  --memory=12288 \
  --disk-size=40g

# 6. Verification
if [ $? -eq 0 ]; then
    echo ""
    echo "=== ✅ Chaos Lab Cluster Created Successfully ==="
    echo "  -> Kubernetes Version: $(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}')"
    echo "  -> Minikube IP: $(minikube ip)"
    echo "  -> Cluster Resources:"
    echo "     • CPUs: 6"
    echo "     • Memory: 12GB"
    echo "     • Disk: 40GB"
    echo ""
    echo "Next steps:"
    echo "  1. kubectl get nodes"
    echo "  2. minikube addons enable dashboard"
    echo "  3. minikube addons enable metrics-server"
else
    echo ""
    echo "=== ❌ Error: Cluster creation failed ==="
    exit 1
fi