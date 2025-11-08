cat > scripts/install-infrastructure.sh <<'EOF'
#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║     Phase 1: Infrastructure Installation                  ║"
echo "║     SRE Resilience Lab: From Manual Response to           ║"
echo "║     Automated Chaos                                       ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 1. Enable Kubernetes Dashboard
echo "[1/5] Enabling Kubernetes Dashboard..."
minikube addons enable dashboard
minikube addons enable metrics-server
echo "  ✓ Dashboard enabled"
echo ""

# 2. Deploy Chaos Target Application
echo "[2/5] Deploying Chaos Target Application..."
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app --timeout=120s
echo "  ✓ Application deployed"
echo ""

# 3. Verify application
echo "[3/5] Verifying application health..."
kubectl get pods -l app=chaos-target-app
echo ""

# 4. Install LitmusChaos Operator
echo "[4/5] Installing LitmusChaos Operator..."
kubectl create namespace litmus
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml -n litmus

echo "  → Waiting for operator pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n litmus --timeout=300s
echo "  ✓ Operator installed"
echo ""

# 5. Install LitmusChaos Portal
echo "[5/5] Installing LitmusChaos Portal (ChaosCenter)..."
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/ 2>/dev/null || true
helm repo update

helm install chaos litmuschaos/litmus \
  --namespace=litmus \
  --set portal.frontend.service.type=NodePort

echo "  → Waiting for Portal pods to be ready (this may take 2-3 minutes)..."
sleep 30

kubectl wait --for=condition=Ready pods \
  -l component=litmusportal-frontend \
  -n litmus --timeout=300s 2>/dev/null || true

kubectl wait --for=condition=Ready pods \
  -l component=litmusportal-server \
  -n litmus --timeout=300s 2>/dev/null || true

echo "  ✓ Portal installed"
echo ""

# 6. Installation Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║     Installation Complete! ✅                              ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Installed Components:"
echo ""
echo "Chaos Target Application:"
kubectl get pods -l app=chaos-target-app -o wide
echo ""
echo "LitmusChaos Infrastructure:"
kubectl get pods -n litmus -o wide
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Access Instructions                                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  Kubernetes Dashboard:"
echo "    minikube dashboard"
echo ""
echo "  LitmusChaos Portal:"
echo "    minikube service chaos-litmus-frontend-service -n litmus"
echo ""
echo "  Default Portal Credentials:"
echo "    Username: admin"
echo "    Password: litmus"
echo ""
echo "🎯 Ready to begin dual-track chaos engineering lab!"
echo ""
echo "Next steps:"
echo "  1. Open Kubernetes Dashboard: minikube dashboard"
echo "  2. Open LitmusChaos Portal: minikube service chaos-litmus-frontend-service -n litmus"
echo "  3. Continue to: track-1-manual-response.md"
echo ""
EOF

chmod +x scripts/install-infrastructure.sh