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
echo "[1/4] Enabling Kubernetes Dashboard and Metrics Server..."
minikube addons enable dashboard
minikube addons enable metrics-server
echo "  ✓ Dashboard and Metrics Server enabled"
echo ""

# 2. Deploy Chaos Target Application
echo "[2/4] Deploying Chaos Target Application..."
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app --timeout=120s
echo "  ✓ Application deployed (3 replicas, stable version)"
echo ""

# 3. Verify application
echo "[3/4] Verifying application health..."
kubectl get pods -l app=chaos-target-app
echo ""

# 4. Install LitmusChaos Operator
echo "[4/4] Installing LitmusChaos Operator (core fault injection engine)..."
kubectl create namespace litmus 2>/dev/null || true
# Apply the core LitmusChaos operator components
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml -n litmus

echo "  → Waiting for operator pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n litmus --timeout=300s
echo "  ✓ LitmusChaos Operator installed"
echo ""

# 5. Installation Summary (Updated)
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║     Installation Complete! ✅                              ║"
echo "║     Portal UI intentionally skipped to focus on IaC        ║"
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
echo "  Kubernetes Dashboard (Monitoring):"
echo "    minikube dashboard"
echo ""
echo "  Chaos Results (Track 2):"
echo "    kubectl get chaosresult -n default"
echo ""
echo "🎯 Ready to begin dual-track chaos engineering lab!"
echo ""
echo "Next steps:"
echo "  1. Open Kubernetes Dashboard to monitor resources: minikube dashboard"
echo "  2. Proceed with the lab tracks, starting with Track 1 (Manual Response)."
echo ""
EOF