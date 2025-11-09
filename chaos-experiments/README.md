# Chaos Experiments Directory

This directory contains ChaosEngine YAML definitions for automated chaos testing.

## What's Here

- `pod-delete-experiment.yaml` - Simple pod deletion chaos
- `cpu-stress-experiment.yaml` - CPU resource exhaustion test
- `network-latency-experiment.yaml` - Network delay injection (optional)

## How to Use
```bash
# Apply a chaos experiment
kubectl apply -f chaos-experiments/pod-delete-experiment.yaml

# Watch chaos execution
kubectl get chaosengine -n default -w

# Check results
kubectl get chaosresult -n default
```

These YAML files are equivalent to creating workflows in the LitmusChaos Portal, but follow Infrastructure as Code principles.
