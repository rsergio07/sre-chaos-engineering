#!/bin/bash
echo "=== Manual Pod Deletion Chaos ==="
echo "Deleting one pod every 15 seconds (4 rounds)"
echo "Starting chaos at: $(date)"
echo ""

for i in {1..4}; do
  PODS=($(kubectl get pods -l app=chaos-target-app -o jsonpath='{.items[*].metadata.name}'))
  POD_TO_DELETE=${PODS[0]}
  
  echo "[$(date '+%H:%M:%S')] Round $i: Deleting pod $POD_TO_DELETE"
  kubectl delete pod "$POD_TO_DELETE" --grace-period=0
  
  sleep 15
done

echo "Chaos completed at: $(date)"
