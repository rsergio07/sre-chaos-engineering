# Track 1: Emergency Rollback Drill (Manual Response)

## Table of Contents

- [Overview](#overview)
- [Learning Objectives](#learning-objectives)
- [Scenario Context](#scenario-context)
- [Exercise 1: Establish Baseline Monitoring](#exercise-1-establish-baseline-monitoring)
- [Exercise 2: Inject Pod Deletion Chaos](#exercise-2-inject-pod-deletion-chaos)
- [Exercise 3: Deploy Unstable Version](#exercise-3-deploy-unstable-version)
- [Exercise 4: Execute Emergency Rollback](#exercise-4-execute-emergency-rollback)
- [Exercise 5: Measure and Document MTTR](#exercise-5-measure-and-document-mttr)
- [Reflection Questions](#reflection-questions)
- [Troubleshooting](#troubleshooting)

---

## Overview

This track simulates the reality of on-call incident response. You will receive an alert about pod failures, assess the situation using kubectl and the Kubernetes Dashboard, and execute an emergency rollback while measuring recovery time. This represents the foundational skill every SRE must master—responding effectively when systems fail unexpectedly during production incidents.

Unlike automated chaos engineering where experiments run on schedules with predefined success criteria, manual response is reactive and time-pressured. You'll experience the stress of troubleshooting under time constraints, the satisfaction of successful recovery, and the limitations of ad-hoc resilience testing. This establishes the baseline against which you'll compare automated approaches in Track 2.

**Expected Time:** 20-30 minutes

**What You'll Practice:**
- Real-time pod monitoring during failures
- Manual chaos injection using kubectl
- Emergency rollback execution under stress
- Manual MTTR measurement and recording
- Post-incident analysis and documentation

---

## Learning Objectives

By completing this track, you will:

1. Establish multi-terminal monitoring workflows that provide real-time visibility into pod states, events, and service availability during chaos scenarios.

2. Inject pod deletion chaos manually using kubectl commands, observing how Kubernetes self-healing mechanisms respond to unexpected failures.

3. Deploy an intentionally broken application version that simulates production deployment failures requiring immediate rollback.

4. Execute emergency rollback procedures using kubectl rollout undo while measuring the elapsed time from failure detection to full recovery.

5. Calculate and document Mean Time to Recovery (MTTR) with contextual information about pod scheduling, image pulls, and health check timing.

6. Analyze the limitations of manual incident response including measurement imprecision, reproducibility challenges, and operational overhead.

---

## Scenario Context

**Time:** Friday, 2:45 PM  
**Situation:** Your team just deployed a security patch to production  
**Alert:** PagerDuty notification - "High pod restart rate on chaos-target-app"  
**Impact:** Customer reports indicate intermittent service errors  
**Your Role:** On-call SRE responsible for service restoration

You open your laptop and see monitoring dashboards lighting up with alerts. Pods are crashing. Customer support is reporting errors. Your engineering manager is asking for status updates in Slack. You have minutes to decide: investigate the root cause or roll back immediately to restore service.

Based on your SRE training, you know the priority is restoring service first, investigating second. You prepare to execute an emergency rollback while your team monitors customer impact. This is that moment.

---

## Exercise 1: Establish Baseline Monitoring

Before injecting any chaos, establish comprehensive monitoring so you can observe system behavior during failures. You'll use three terminals with different views of cluster state.

### Terminal 1: Continuous Pod Monitoring

Open your first terminal and establish a live watch on pod states.

```bash
# Watch pod states in real-time
kubectl get pods -l app=chaos-target-app -w
```

The `-w` flag (watch) keeps kubectl running and updates the display whenever pod states change. You'll see transitions like:
- `Running` → `Terminating` (when pods are deleted)
- `Pending` → `ContainerCreating` → `Running` (when replacements start)
- `CrashLoopBackOff` (when containers fail repeatedly)

**Leave this running.** The continuous output provides your primary view of pod lifecycle during chaos.

**Expected initial output:**
```
NAME                                READY   STATUS    RESTARTS   AGE
chaos-target-app-xxxxx-xxxxx        1/1     Running   0          10m
chaos-target-app-xxxxx-xxxxx        1/1     Running   0          10m
chaos-target-app-xxxxx-xxxxx        1/1     Running   0          10m
```

### Terminal 2: Service Availability Monitoring

Open a second terminal to continuously test service availability from the client perspective.

First, verify port-forward is running:

```bash
# Check if port-forward is active
ps aux | grep "port-forward.*chaos-target-service"
```

If not running, start it:

```bash
# Start port-forward to service
kubectl port-forward svc/chaos-target-service 8080:80 --address 0.0.0.0 &
PORT_FORWARD_PID=$!
echo "Port-forward PID: $PORT_FORWARD_PID"
sleep 3
```

Now create a monitoring loop that continuously tests the service:

```bash
# Create availability monitoring script
cat > /tmp/monitor-availability.sh <<'EOF'
#!/bin/bash
echo "=== Service Availability Monitor ==="
echo "Testing http://localhost:8080 every 3 seconds"
echo "Press Ctrl+C to stop"
echo ""

SUCCESS_COUNT=0
FAILURE_COUNT=0

while true; do
  TIMESTAMP=$(date '+%H:%M:%S')
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
  
  if [ "$STATUS" = "200" ]; then
    echo "[$TIMESTAMP] ✓ HTTP $STATUS - Service available"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "[$TIMESTAMP] ✗ HTTP $STATUS - Service degraded"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
  fi
  
  sleep 3
done
EOF

chmod +x /tmp/monitor-availability.sh
```

Run the monitoring script:

```bash
# Start availability monitoring
/tmp/monitor-availability.sh
```

**Expected output:**
```
=== Service Availability Monitor ===
Testing http://localhost:8080 every 3 seconds
Press Ctrl+C to stop

[14:50:01] ✓ HTTP 200 - Service available
[14:50:04] ✓ HTTP 200 - Service available
[14:50:07] ✓ HTTP 200 - Service available
```

**Leave this running.** You'll see availability drop to HTTP 000 when chaos impacts the service.

### Terminal 3: Command Execution Terminal

Open a third terminal for executing chaos injection commands and rollback procedures. This is your "operator" terminal where you'll trigger actions and measure timing.

Verify you can execute commands:

```bash
# Verify kubectl works
kubectl get deployment chaos-target-app

# Verify you can see events
kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
```

### Open Kubernetes Dashboard

In addition to the three terminals, open the Kubernetes Dashboard for visual monitoring:

```bash
# Open dashboard (in a new terminal or background)
minikube dashboard &
```

The dashboard automatically opens in your browser. Navigate to:
1. Click "Workloads" → "Deployments"
2. Select namespace: "default"
3. Click on "chaos-target-app" deployment
4. Keep this view open to watch pod state changes visually

**Monitoring Setup Complete.** You now have:
- Terminal 1: Live pod status updates
- Terminal 2: Continuous service availability testing
- Terminal 3: Ready for command execution
- Browser: Visual dashboard showing cluster state

---

## Exercise 2: Inject Pod Deletion Chaos

Now simulate production pod failures by manually deleting pods and observing how Kubernetes responds. This chaos represents pods crashing due to application bugs, out-of-memory kills, or node failures.

### Understand What Will Happen

When you delete a pod:
1. Pod enters `Terminating` state immediately
2. Kubernetes sends SIGTERM to the container
3. After grace period, pod is forcefully removed
4. Deployment's ReplicaSet controller detects missing replica
5. ReplicaSet schedules a replacement pod
6. New pod goes: `Pending` → `ContainerCreating` → `Running`
7. Health checks must pass before pod is marked Ready

### Execute Single Pod Deletion

In **Terminal 3**, delete one pod and observe the recovery process:

```bash
# Get list of current pods
kubectl get pods -l app=chaos-target-app

# Delete the first pod (force immediate termination)
kubectl delete pod $(kubectl get pods -l app=chaos-target-app -o jsonpath='{.items[0].metadata.name}') --grace-period=0 --force
```

**Expected output:**
```
warning: Immediate deletion does not wait for confirmation that the running resource has been terminated. The resource may continue to run on the cluster indefinitely.
pod "chaos-target-app-xxxxx-xxxxx" force deleted
```

### Observe Recovery in All Monitors

Watch what happens across your monitoring setup:

**Terminal 1 (Pod Watch):**
```
chaos-target-app-xxxxx-xxxxx   1/1   Terminating   0     10m
chaos-target-app-xxxxx-xxxxx   0/1   Terminating   0     10m
chaos-target-app-xxxxx-lmnop   0/1   Pending       0     0s
chaos-target-app-xxxxx-lmnop   0/1   ContainerCreating   0   1s
chaos-target-app-xxxxx-lmnop   1/1   Running             0   8s
```

**Terminal 2 (Availability Monitor):**
```
[14:55:01] ✓ HTTP 200 - Service available
[14:55:04] ✗ HTTP 000 - Service degraded  ← Brief disruption
[14:55:07] ✗ HTTP 000 - Service degraded
[14:55:10] ✓ HTTP 200 - Service available  ← Recovery
```

**Dashboard:**
- Pod count briefly shows 2/3 ready
- Events log shows pod deletion and creation
- Deployment status updates to show progress

### Measure Single Pod Recovery Time

```bash
# Check how long recovery took
kubectl get pods -l app=chaos-target-app

# View recent events with timing
kubectl get events --sort-by=.metadata.creationTimestamp | grep chaos-target-app | tail -5
```

**Typical recovery time:** 10-20 seconds from deletion to new pod Ready.

### Execute Continuous Pod Deletion

Now simulate sustained pod failures by continuously deleting pods over 60 seconds:

```bash
# Run the existing chaos script
./scripts/manual-pod-chaos.sh
```

**Expected output:**
```
=== Manual Pod Deletion Chaos ===
Deleting one pod every 15 seconds (4 rounds)
Starting chaos at: Fri Nov  8 14:56:00 CST 2024

[14:56:00] Round 1: Deleting pod chaos-target-app-xxxxx-aaaaa
pod "chaos-target-app-xxxxx-aaaaa" deleted
[14:56:16] Round 2: Deleting pod chaos-target-app-xxxxx-bbbbb
pod "chaos-target-app-xxxxx-bbbbb" deleted
[14:56:32] Round 3: Deleting pod chaos-target-app-xxxxx-ccccc
pod "chaos-target-app-xxxxx-ccccc" deleted
[14:56:48] Round 4: Deleting pod chaos-target-app-xxxxx-ddddd
pod "chaos-target-app-xxxxx-ddddd" deleted
Chaos completed at: Fri Nov  8 14:57:04 CST 2024
```

**Observe in Terminal 1:** Continuous pod churn as pods are deleted and recreated.

**Observe in Terminal 2:** Intermittent service availability drops as requests hit terminating pods.

### Analyze Chaos Impact

| Metric | Observation |
| :--- | :--- |
| **Response Time (Latency)** | Highly variable, spiking to several seconds immediately after each pod deletion. |
| **Availability** | Degradation observed; the service experienced brief periods of total unresponsiveness (`HTTP 000000`). This happened because the targeted pod that was holding the `kubectl port-forward` connection was forcefully terminated by the chaos injection. |
| **Pod Status** | All deleted pods were rapidly terminated and recreated by the ReplicaSet, but the new pods took 5-10 seconds to transition to the `Ready` state. |

**Key Observation: Resilience vs. Access Fragility**

Kubernetes' core **self-healing mechanisms** (the ReplicaSet) worked exactly as designed: it detected the missing pod and immediately created a replacement. This ensures the service's eventual availability.

However, the **service was degraded**, and the external monitoring connection failed. This highlights that while the *service itself* recovers quickly, **the tools and access methods used for monitoring can be the most fragile component** during a chaos event. This manual observation serves as the baseline for our automated test, where we expect better metrics.

#### Recovery Step

The service is running, but the local connection is dead. To restore a robust monitoring connection that will survive future pod deletions, we should forward the port directly to the Service resource.

- **Start Port Forward:**
    ```bash
    kubectl port-forward svc/chaos-target-service 8080:80 --address 0.0.0.0 &
    ```

This command will automatically reconnect to a healthy backend pod when a pod is deleted, ensuring a stable connection for continuous monitoring.

---

## Exercise 3: Deploy Unstable Version

Now simulate a failed production deployment by applying the unstable manifest that uses a nonexistent container image. This creates the scenario requiring emergency rollback.

### Record Pre-Deployment State

Before deploying the broken version, document the current stable state:

```bash
# Record current deployment revision
kubectl rollout history deployment/chaos-target-app

# Record current image
kubectl get deployment chaos-target-app -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

# Record current pod age
kubectl get pods -l app=chaos-target-app -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp
```

**Expected output:**
```
deployment.apps/chaos-target-app 
REVISION  CHANGE-CAUSE
1         <none>

nginx:1.21-alpine

NAME                                CREATIONTIMESTAMP
chaos-target-app-xxxxx-aaaaa        2024-11-08T20:45:00Z
chaos-target-app-xxxxx-bbbbb        2024-11-08T20:45:00Z
chaos-target-app-xxxxx-ccccc        2024-11-08T20:45:00Z
```

This is revision 1 using a stable nginx image.

### Deploy Unstable Version

Apply the unstable manifests that contain the broken image reference:

```bash
# Deploy broken version
kubectl apply -f manifests/unstable/

# Immediately check rollout status
kubectl rollout status deployment/chaos-target-app --timeout=30s
```

**Expected output:**
```
configmap/app-content-unstable created
deployment.apps/chaos-target-app configured
service/chaos-target-service unchanged
Waiting for deployment "chaos-target-app" rollout to finish: 1 out of 3 new replicas have been updated...
```

The rollout will hang because new pods cannot start.

### Observe Deployment Failure

**Terminal 1 (Pod Watch):** Shows new pods stuck in `ImagePullBackOff`:
```
chaos-target-app-xxxxx-aaaaa   1/1   Running              0    15m
chaos-target-app-xxxxx-bbbbb   1/1   Running              0    15m
chaos-target-app-xxxxx-ccccc   1/1   Running              0    15m
chaos-target-app-yyyyy-ddddd   0/1   ImagePullBackOff     0    30s
```

**Terminal 2 (Availability Monitor):** Still shows HTTP 200 because old pods remain running:
```
[15:00:01] ✓ HTTP 200 - Service available
[15:00:04] ✓ HTTP 200 - Service available
```

**Dashboard:** Shows mixed pod states - some Running (old), some ImagePullBackOff (new).

### Investigate the Failure

As the on-call SRE, you need to quickly diagnose why the deployment failed:

```bash
# Check pod status details
kubectl get pods -l app=chaos-target-app

# Describe the failing pod
kubectl describe pod $(kubectl get pods -l app=chaos-target-app | grep ImagePullBackOff | head -1 | awk '{print $1}')
```

**Key output from describe:**
```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  45s                default-scheduler  Successfully assigned default/chaos-target-app-yyyyy-ddddd to minikube
  Normal   Pulling    15s (x3 over 43s)  kubelet            Pulling image "nginx:nonexistent-tag"
  Warning  Failed     14s (x3 over 42s)  kubelet            Failed to pull image "nginx:nonexistent-tag": rpc error: code = NotFound desc = failed to pull and unpack image "docker.io/library/nginx:nonexistent-tag": docker.io/library/nginx:nonexistent-tag: not found
  Warning  Failed     14s (x3 over 42s)  kubelet            Error: ErrImagePull
```

**Root Cause Identified:** The deployment references `nginx:nonexistent-tag` which doesn't exist in Docker Hub.

### Decision Point: Rollback or Debug?

In a real production incident, you face a critical decision:

**Option A: Debug and Fix**
- Investigate why the wrong image was used
- Update deployment with correct image
- Risk: Additional downtime while troubleshooting
- Benefit: Deploy the intended fix

**Option B: Rollback Immediately**
- Revert to last known-good version
- Restore service quickly
- Risk: Security patch not applied
- Benefit: Minimal customer impact

**SRE Best Practice:** Rollback first, investigate second. The priority is restoring service. You can redeploy the correct fix after service is stable.

---

## Exercise 4: Execute Emergency Rollback

Now execute the emergency rollback procedure while measuring precise timing. This simulates the time-pressured recovery during a real production incident.

### Prepare Timing Measurement

You'll measure MTTR from the moment you initiate rollback until all pods are healthy.

```bash
# Note the current time
date '+%H:%M:%S'
```

### Initiate Rollback

Execute the rollback command:

```bash
# Start timing (note this exact second)
echo "Rollback started at: $(date '+%H:%M:%S')"

# Execute rollback
kubectl rollout undo deployment/chaos-target-app
```

**Expected output:**
```
Rollback started at: 15:02:30
deployment.apps/chaos-target-app rolled back
```

The rollback command tells Kubernetes to revert the Deployment to the previous revision (revision 1 with the stable image).

### Monitor Rollback Progress

Watch the rollback execution across your monitors:

**Terminal 1 (Pod Watch):**
```
chaos-target-app-yyyyy-ddddd   0/1   ImagePullBackOff   0    2m   ← Old broken pod
chaos-target-app-yyyyy-ddddd   0/1   Terminating        0    2m   ← Being terminated
chaos-target-app-zzzzz-eeee    0/1   Pending            0    0s   ← New stable pod
chaos-target-app-zzzzz-eeee    0/1   ContainerCreating  0    1s
chaos-target-app-zzzzz-eeee    1/1   Running            0    8s
```

**Terminal 3 (Command Terminal):**

Check rollout status:

```bash
# Watch rollout progress
kubectl rollout status deployment/chaos-target-app --timeout=300s
```

**Expected output:**
```
Waiting for deployment "chaos-target-app" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "chaos-target-app" rollout to finish: 1 old replicas are pending termination...
deployment "chaos-target-app" successfully rolled out
```

### Record Completion Time

When rollout status reports success:

```bash
# Note completion time
echo "Rollback completed at: $(date '+%H:%M:%S')"
```

### Calculate MTTR

Calculate the elapsed time manually:

```bash
# Example calculation:
# Start time: 15:02:30
# End time:   15:03:12
# MTTR = 42 seconds
```

**Typical MTTR for this scenario:** 30-60 seconds, depending on:
- Image pull time (if nginx:1.21-alpine not cached)
- Pod scheduling speed
- Health check timing (readiness probe must pass)

---

## Exercise 5: Measure and Document MTTR

Now document the complete recovery metrics and contextual information that explains your MTTR measurement.

### Verify Full Recovery

Confirm the system is completely healthy:

```bash
# All pods should be Running with Ready 1/1
kubectl get pods -l app=chaos-target-app

# Deployment should show 3/3 ready
kubectl get deployment chaos-target-app

# Service should have three endpoints
kubectl get endpoints chaos-target-service

# Check revision history
kubectl rollout history deployment/chaos-target-app
```

**Expected output:**
```
NAME                                READY   STATUS    RESTARTS   AGE
chaos-target-app-zzzzz-eeee         1/1     Running   0          2m
chaos-target-app-zzzzz-ffff         1/1     Running   0          2m
chaos-target-app-zzzzz-gggg         1/1     Running   0          2m

NAME               READY   UP-TO-DATE   AVAILABLE   AGE
chaos-target-app   3/3     3            3           25m

NAME                   ENDPOINTS                                      AGE
chaos-target-service   10.244.0.10:80,10.244.0.11:80,10.244.0.12:80  25m

deployment.apps/chaos-target-app 
REVISION  CHANGE-CAUSE
2         <none>
3         <none>
```

Note: Revision 2 was the failed deployment, revision 3 is the rollback to revision 1's configuration.

### Stop Availability Monitor

In **Terminal 2**, press `Ctrl+C` to stop the monitoring script.

Review the output to count successes vs failures:

```
=== Service Availability Monitor ===
...
[15:02:20] ✓ HTTP 200 - Service available
[15:02:23] ✓ HTTP 200 - Service available  ← Last success before rollback
[15:02:26] ✓ HTTP 200 - Service available
[15:02:29] ✓ HTTP 200 - Service available  ← During rollback (old pods still serving)
[15:02:32] ✓ HTTP 200 - Service available
...
[15:03:15] ✓ HTTP 200 - Service available  ← Full recovery confirmed
```

**Key Insight:** Service remained available throughout rollback because Kubernetes kept old stable pods running while replacing broken pods.

### Document MTTR Report

Create a structured report documenting your manual chaos experiment:

```bash
cat > manual-chaos-report.md <<EOF
# Manual Chaos Engineering Report - Track 1

## Test Environment
- **Date:** $(date)
- **Kubernetes Version:** $(kubectl version --short | grep Server)
- **Cluster:** $(kubectl config current-context)
- **Application:** chaos-target-app (3 replicas)

## Experiment Summary

### Chaos Scenario: Pod Deletion
- **Type:** Manual pod deletion using kubectl
- **Duration:** 60 seconds (4 deletion rounds, 15s intervals)
- **Impact:** Brief service disruptions (1-3 seconds per deletion)
- **Recovery:** Automatic via Kubernetes ReplicaSet controller

### Deployment Failure Scenario
- **Failure Type:** ImagePullBackOff due to nonexistent image tag
- **Detection Time:** Immediate (visible in kubectl rollout status)
- **Affected Replicas:** 1 of 3 (rolling update strategy preserved availability)
- **Service Impact:** None (old pods continued serving traffic)

## MTTR Measurement

### Manual Rollback
- **Start Time:** [Your recorded start time, e.g., 15:02:30]
- **End Time:** [Your recorded end time, e.g., 15:03:12]
- **MTTR:** [Your calculated MTTR, e.g., 42 seconds]

### MTTR Components
- Rollback command execution: <1 second
- Pod termination grace period: ~5 seconds
- New pod scheduling: ~2 seconds
- Container image pull: ~15-30 seconds (if not cached)
- Container startup: ~2 seconds
- Readiness probe passes: ~5 seconds

### Factors Affecting MTTR
- Image already cached on node: Yes/No [check your case]
- Concurrent pod deletions during rollback: No
- Resource constraints: None observed
- Network latency: Minimal (local Minikube)

## Key Findings

### What Worked Well
- Kubernetes self-healing automatically replaced deleted pods
- Rolling update strategy prevented complete service outage
- Rollback procedure succeeded without manual intervention
- Service remained available throughout rollback

### Limitations Observed
- Manual MTTR measurement imprecise (human reaction time)
- No automated pass/fail criteria for recovery success
- Difficult to reproduce exact conditions for comparison
- Requires dedicated engineer time for each test

### Service Availability
- **Total test duration:** ~5 minutes
- **Observed downtime:** <10 seconds total (brief disruptions during pod deletion)
- **Availability:** ~99.9% during test period

## Lessons Learned

1. **Kubernetes resilience:** Self-healing worked as expected, replacing failed pods automatically
2. **Rollback effectiveness:** Emergency rollback restored service in under 60 seconds
3. **Monitoring importance:** Multi-terminal monitoring provided comprehensive view of system behavior
4. **Manual measurement challenges:** Precise MTTR difficult to capture consistently

## Recommendations

1. Automate MTTR measurement to eliminate human timing errors
2. Define objective success criteria before experiments
3. Schedule regular chaos testing rather than waiting for production incidents
4. Consider automated chaos platforms for reproducible testing

---
**Report Generated:** $(date)
**Engineer:** [Your name]
EOF

# Display the report
cat manual-chaos-report.md
```

### Commit Your Work

Save your experiment results to version control:

```bash
# Add the report
git add manual-chaos-report.md

# Commit with descriptive message
git commit -m "Track 1 complete: Manual chaos with MTTR measurement

- Executed pod deletion chaos (4 rounds over 60s)
- Deployed unstable version with broken image
- Performed emergency rollback successfully
- Measured MTTR: [your MTTR] seconds
- Documented complete experiment in report"

# Push to repository
git push origin main
```

---

## Reflection Questions

Take a few minutes to reflect on this manual chaos experience:

### Technical Reflection

1. **How accurate was your MTTR measurement?** Consider the challenges of starting/stopping timing manually during a stressful incident.

2. **Could you reproduce this exact experiment?** What variables might change if you ran this test again tomorrow?

3. **How did Kubernetes self-healing compare to your expectations?** Were there any surprises in how pods were replaced?

4. **What would happen with higher pod deletion rates?** If you deleted pods every 5 seconds instead of 15, how would that affect service availability?

### Operational Reflection

5. **How would this scale with 10 different services?** Could you manually run chaos tests on multiple applications weekly?

6. **What if this happened at 2 AM?** How would the pressure of a real incident affect your timing accuracy and decision-making?

7. **How do you share these results with your team?** Is a markdown file sufficient, or would you need graphs and trend analysis?

8. **What success criteria did you use?** How did you decide the rollback was "successful" - was it subjective or objective?

### Improvement Opportunities

9. **What took the longest during rollback?** Image pulls? Pod scheduling? Health checks? How could you optimize each?

10. **What monitoring was missing?** What additional data would help you understand system behavior during chaos?

---

## Troubleshooting

### Rollback Command Shows "No Rollout History"

**Symptoms:**
```bash
kubectl rollout undo deployment/chaos-target-app
```
Returns error: "no rollout history found"

**Cause:**
Deployment doesn't have previous revisions stored.

**Resolution:**

Check rollout history:
```bash
kubectl rollout history deployment/chaos-target-app
```

If only showing one revision, you cannot rollback. Instead, manually reapply stable manifests:
```bash
kubectl apply -f manifests/stable/
kubectl rollout status deployment/chaos-target-app
```

---

### Pods Still in ImagePullBackOff After Rollback

**Symptoms:**
Rollback completed but some pods remain in ImagePullBackOff state.

**Diagnosis:**
```bash
kubectl get pods -l app=chaos-target-app
kubectl describe pod <failing-pod-name>
```

**Cause:**
Rollback may not have fully propagated or there's a manifest conflict.

**Resolution:**

Force recreation of all pods:
```bash
kubectl rollout restart deployment/chaos-target-app
```

Or delete failing pods manually:
```bash
kubectl delete pod <failing-pod-name>
```

ReplicaSet will create replacements using the correct (rolled-back) configuration.

---

### Service Became Completely Unavailable

**Symptoms:**
Availability monitor showed HTTP 000 for extended period (>30 seconds).

**Diagnosis:**
```bash
kubectl get endpoints chaos-target-service
kubectl get pods -l app=chaos-target-app
```

**Cause:**
Likely all pods were in failed state simultaneously, or service selector mismatch.

**Resolution:**

Verify service selector matches pod labels:
```bash
kubectl get service chaos-target-service -o yaml | grep -A 3 selector
kubectl get pods -l app=chaos-target-app --show-labels
```

If mismatch, update service or redeploy pods with correct labels.

---

### MTTR Seems Unrealistically Long

**Symptoms:**
Rollback took >2 minutes despite no obvious issues.

**Diagnosis:**
```bash
kubectl get events --sort-by=.metadata.creationTimestamp | grep chaos-target-app
```

Look for delays in:
- Image pull (check for "Pulling image" messages)
- Pod scheduling (check for "FailedScheduling" warnings)
- Health checks (check readiness probe timing)

**Resolution:**

Pre-pull images to reduce MTTR:
```bash
minikube ssh -- docker pull nginx:1.21-alpine
```

Adjust health check timing if probes are too conservative:
```bash
kubectl edit deployment chaos-target-app
# Reduce initialDelaySeconds and periodSeconds in readinessProbe
```

---

## Next Steps

You've now completed manual chaos engineering and measured baseline MTTR through reactive incident response. You experienced the stress of real-time troubleshooting, the satisfaction of successful recovery, and the limitations of manual measurement.

**Continue to Track 2** to see how automated chaos engineering addresses these limitations:

[Track 2: Scheduled Resilience Testing (Automated Chaos)](track-2-automated-chaos.md)

In Track 2, you'll:
- Design chaos experiments using LitmusChaos Portal's visual workflow builder
- Define hypothesis-driven success criteria before experiments run
- Let the platform measure MTTR automatically with millisecond precision
- Schedule experiments to run without human intervention
- Compare automated MTTR measurements against your manual baseline

**Or skip to final analysis:**

[Final Phase: Comparative Analysis & Cleanup](final-phase-analysis.md)

This phase guides you through comparing manual vs automated approaches and generating a comprehensive report on operational maturity differences.