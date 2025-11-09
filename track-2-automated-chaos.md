# Track 2: Scheduled Resilience Testing (Automated Chaos)

## Table of Contents

- [Overview](#overview)
- [Learning Objectives](#learning-objectives)
- [Scenario Context](#scenario-context)
- [Exercise 1: Understand ChaosEngine Architecture](#exercise-1-understand-chaosengine-architecture)
- [Exercise 2: Execute Pod Delete Chaos](#exercise-2-execute-pod-delete-chaos)
- [Exercise 3: Execute CPU Stress Chaos](#exercise-3-execute-cpu-stress-chaos)
- [Exercise 4: Analyze Automated Results](#exercise-4-analyze-automated-results)
- [Exercise 5: Compare with Manual Approach](#exercise-5-compare-with-manual-approach)
- [Reflection Questions](#reflection-questions)
- [Troubleshooting](#troubleshooting)

---

## Overview

This track demonstrates the evolution from reactive incident response to proactive resilience validation. Instead of manually triggering chaos and measuring recovery with stopwatches, you'll define chaos experiments as code using ChaosEngine YAML manifests. The LitmusChaos operator executes these experiments automatically, measures outcomes precisely, and generates structured results without human intervention.

Unlike Track 1's manual approach where you executed commands in real-time, automated chaos uses declarative specifications. You define what failure to inject, what success looks like, and when to run the test. The platform handles execution, measurement, and reporting. This is how mature SRE teams systematically test resilience at scale.

**Expected Time:** 30-40 minutes

**What You'll Learn:**
- ChaosEngine custom resource structure and specifications
- Declarative chaos experiment design
- Automated probe-based validation
- Structured chaos result analysis
- Infrastructure as Code approach to chaos engineering

---

## Learning Objectives

By completing this track, you will:

1. Understand ChaosEngine architecture and how declarative YAML definitions specify chaos experiments, target selection, and success criteria.

2. Execute automated pod deletion chaos experiments that run without manual intervention, using the LitmusChaos operator to handle fault injection and recovery measurement.

3. Design and execute CPU stress experiments with continuous HTTP probes that validate service availability throughout the chaos period.

4. Analyze ChaosResult custom resources containing structured experiment outcomes, probe success rates, and detailed execution logs.

5. Compare automated YAML-based chaos against manual kubectl approaches to quantify differences in reproducibility, measurement precision, and operational overhead.

6. Apply Infrastructure as Code principles to chaos engineering by version-controlling experiment definitions and treating resilience testing as code.

---

## Scenario Context

**Time:** Monday morning, weekly SRE team meeting  
**Discussion:** Last Friday's incident review  
**Decision:** Implement proactive chaos testing  
**Your Task:** Design automated resilience validation using ChaosEngine YAML

Your team reviewed Friday's rollback incident and recognized a pattern: most production issues occur during Friday afternoon deployments when the team is least prepared for weekend on-call. Your manager asks, "How can we test our rollback procedures every Friday without requiring engineer time and without causing actual outages?"

This is where automated chaos engineering using YAML definitions provides the answer. Instead of using a web UI (LitmusChaos Portal), you'll define chaos experiments as version-controlled YAML files. This Infrastructure as Code approach means experiments are:
- **Reproducible:** Exact same conditions every execution
- **Version-controlled:** Track experiment changes in Git
- **Schedulable:** Run via CI/CD or Kubernetes CronJobs
- **Reviewable:** Code review chaos experiments like application code

---

## Exercise 1: Understand ChaosEngine Architecture

Before executing chaos, understand how LitmusChaos uses Kubernetes custom resources to orchestrate experiments.

### ChaosEngine Components

A ChaosEngine defines three key aspects:

**1. Target Application (appinfo)**
````yaml
appinfo:
  appns: 'default'              # Namespace of target application
  applabel: 'app=chaos-target-app'  # Label selector for target pods
  appkind: 'deployment'         # Resource type (deployment, statefulset, etc.)
````

**2. Experiment Specification (experiments)**
````yaml
experiments:
  - name: pod-delete            # Which chaos experiment to run
    spec:
      components:
        env:
          - name: TOTAL_CHAOS_DURATION
            value: '60'         # Duration in seconds
          - name: CHAOS_INTERVAL
            value: '10'         # Time between chaos actions
````

**3. Success Validation (probe)**
````yaml
probe:
  - name: check-availability
    type: httpProbe             # Probe type (http, cmd, k8s, prometheus)
    mode: Continuous            # When to run (Continuous, EOT, Edge)
    httpProbe/inputs:
      url: http://service:80    # What to check
      method:
        get:
          criteria: ==
          responseCode: "200"   # What success looks like
````

### How Chaos Executes
````
1. You apply ChaosEngine YAML
   ↓
2. LitmusChaos Operator detects new ChaosEngine
   ↓
3. Operator creates chaos-runner pod
   ↓
4. Runner pod creates experiment job
   ↓
5. Experiment job injects fault (deletes pod, stresses CPU, etc.)
   ↓
6. Probes continuously validate system behavior
   ↓
7. Experiment completes, creates ChaosResult
   ↓
8. ChaosResult contains verdict (Pass/Fail) and detailed metrics
````

### View Existing Experiments
````bash
# List installed chaos experiments
kubectl get chaosexperiment -n default

# View pod-delete experiment definition
kubectl get chaosexperiment pod-delete -n default -o yaml | less
````

**Key observation:** The ChaosExperiment CRD defines HOW to inject a specific fault. The ChaosEngine CRD defines WHEN and WHERE to inject it.

### Inspect Your Chaos Infrastructure
````bash
# Verify operator is running
kubectl get pods -n litmus -l app.kubernetes.io/component=operator

# Check RBAC is configured
kubectl get sa litmus-admin -n default
kubectl get clusterrole litmus-admin
kubectl get clusterrolebinding litmus-admin

# List available chaos experiments
kubectl get chaosexperiment -n default
````

**Expected output:**
````
NAME           AGE
pod-delete     10m
pod-cpu-hog    10m
````

---

## Exercise 2: Execute Pod Delete Chaos

Run an automated pod deletion experiment that executes for 90 seconds, deleting pods every 10 seconds while continuously validating service availability.

### Review the Experiment Definition
````bash
# View the observable pod delete experiment
cat chaos-experiments/pod-delete-observable.yaml
````

**Key sections to understand:**

**Target Selection:**
````yaml
appinfo:
  appns: 'default'
  applabel: 'app=chaos-target-app'
  appkind: 'deployment'
````
This tells LitmusChaos to find deployment pods with label `app=chaos-target-app` in the default namespace.

**Chaos Parameters:**
````yaml
env:
  - name: TOTAL_CHAOS_DURATION
    value: '90'           # Run for 90 seconds
  - name: CHAOS_INTERVAL
    value: '10'           # Delete pod every 10 seconds
  - name: FORCE
    value: 'true'         # Force immediate termination
  - name: PODS_AFFECTED_PERC
    value: '33'           # Affect 33% of pods (1 of 3)
````

**Job Cleanup Policy:**
````yaml
jobCleanUpPolicy: 'retain'
````
This keeps chaos resources after completion so you can inspect logs and results.

### Execute the Experiment

Open **two terminals** for observation:

**Terminal 1: Watch Target Pods**
````bash
# Continuously watch pod state changes
kubectl get pods -l app=chaos-target-app -w
````

**Terminal 2: Execute Chaos**
````bash
# Apply the chaos experiment
kubectl apply -f chaos-experiments/pod-delete-observable.yaml

# Watch chaos engine status
watch -n 2 'kubectl get chaosengine pod-delete-observable -n default'
````

### Observe Chaos Execution

**In Terminal 1**, you'll see pod lifecycle transitions:
````
NAME                                READY   STATUS    RESTARTS   AGE
chaos-target-app-xxxxx-aaaaa        1/1     Running   0          5m
chaos-target-app-xxxxx-bbbbb        1/1     Running   0          5m
chaos-target-app-xxxxx-ccccc        1/1     Running   0          5m
chaos-target-app-xxxxx-aaaaa        1/1     Terminating   0      5m    ← Chaos deletes pod
chaos-target-app-xxxxx-ddddd        0/1     Pending       0      0s    ← Replacement scheduled
chaos-target-app-xxxxx-ddddd        0/1     ContainerCreating   0  1s
chaos-target-app-xxxxx-aaaaa        0/1     Terminating   0      5m
chaos-target-app-xxxxx-ddddd        1/1     Running       0      8s    ← New pod ready
````

**In Terminal 2**, you'll see chaos engine progression:
````
NAME                     AGE
pod-delete-observable    10s    ← Initial state
pod-delete-observable    30s    ← Running
pod-delete-observable    100s   ← Completed
````

### Monitor Chaos Jobs

While chaos is running:
````bash
# Check chaos runner pod
kubectl get pods -n default | grep pod-delete-observable

# Check chaos experiment job
kubectl get jobs -n default | grep pod-delete

# View runner logs in real-time
kubectl logs -f -n default pod-delete-observable-runner
````

### Wait for Completion

The experiment runs for 90 seconds. Wait for completion:
````bash
# Wait for chaos to complete (should take ~100 seconds total)
sleep 110

# Verify completion
kubectl get chaosengine pod-delete-observable -n default
````

### Verify Target Application Health

After chaos completes, verify the application recovered:
````bash
# All pods should be Running
kubectl get pods -l app=chaos-target-app

# Check restart counts (should still be 0 - pods were deleted, not restarted)
kubectl get pods -l app=chaos-target-app -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount

# Verify service has healthy endpoints
kubectl get endpoints chaos-target-service
````

**Expected results:**
- Three pods in `Running` state
- All pods showing `RESTARTS: 0`
- Service has three healthy endpoints

---

## Exercise 3: Execute CPU Stress Chaos

Now run a more complex experiment that stresses CPU resources while continuously validating service availability through HTTP probes.

### Review CPU Stress Experiment
````bash
# View the CPU stress experiment definition
cat chaos-experiments/cpu-stress-experiment.yaml
````

**Key differences from pod deletion:**

**1. Different fault type:**
````yaml
experiments:
  - name: pod-cpu-hog    # Stresses CPU instead of deleting pods
````

**2. CPU-specific parameters:**
````yaml
env:
  - name: CPU_CORES
    value: '1'           # Stress 1 CPU core
  - name: CPU_LOAD
    value: '100'         # 100% load on that core
  - name: PODS_AFFECTED_PERC
    value: '33'          # Affect 1 of 3 pods
````

**3. Multiple probes:**
````yaml
probe:
  - name: check-service-availability
    type: httpProbe      # HTTP endpoint check
  - name: check-pod-status
    type: cmdProbe       # Command-based check
````

### Clean Up Previous Experiment
````bash
# Delete pod delete chaos engine
kubectl delete chaosengine pod-delete-observable -n default

# Optional: Clean up completed pods/jobs
kubectl delete pods -n default -l chaosUID
kubectl delete jobs -n default -l chaosUID
````

### Execute CPU Stress Experiment

**Terminal 1: Watch Target Pods**
````bash
# Watch pod resource usage (if metrics-server is enabled)
watch -n 2 'kubectl top pods -l app=chaos-target-app 2>/dev/null || kubectl get pods -l app=chaos-target-app'
````

**Terminal 2: Execute Chaos**
````bash
# Apply CPU stress chaos
kubectl apply -f chaos-experiments/cpu-stress-experiment.yaml

# Watch execution
watch -n 2 'kubectl get chaosengine cpu-stress-chaos -n default && echo "" && kubectl get jobs -n default | grep cpu'
````

### Observe CPU Stress Behavior

Unlike pod deletion where pods are terminated, CPU stress keeps pods running but consumes their CPU resources:
````bash
# Check CPU usage on target pods (requires metrics-server)
kubectl top pods -l app=chaos-target-app

# Check chaos experiment helper pod
kubectl get pods -n default | grep cpu-hog

# View experiment logs
kubectl logs -n default -l name=pod-cpu-hog -f
````

**Expected observations:**
- Target pods remain in `Running` state (not terminated)
- One pod shows elevated CPU usage
- Service continues responding (other pods handle traffic)
- No pod restarts

### Monitor Service Availability

Test service availability during CPU stress:
````bash
# Ensure port-forward is running
kubectl port-forward svc/chaos-target-service 8080:80 --address 0.0.0.0 &

# Test service availability during chaos
for i in {1..20}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
  echo "$(date '+%H:%M:%S') - HTTP $STATUS"
  sleep 5
done
````

**Expected output:**
````
18:30:01 - HTTP 200
18:30:06 - HTTP 200
18:30:11 - HTTP 200  ← CPU stress running
18:30:16 - HTTP 200  ← Service still available
18:30:21 - HTTP 200
````

Service should remain available because:
- Only 1 of 3 pods is stressed
- Resource limits prevent complete CPU monopolization
- Kubernetes routes traffic to healthy pods

### Wait for Completion

CPU stress runs for 120 seconds:
````bash
# Wait for completion
sleep 130

# Verify completion
kubectl get chaosengine cpu-stress-chaos -n default
````

---

## Exercise 4: Analyze Automated Results

Now examine the structured results that LitmusChaos automatically generated during both experiments.

### View ChaosResults
````bash
# List all chaos results
kubectl get chaosresult -n default

# View pod delete results
kubectl get chaosresult pod-delete-observable-pod-delete -n default -o yaml | less

# View CPU stress results
kubectl get chaosresult cpu-stress-chaos-pod-cpu-hog -n default -o yaml | less
````

### Extract Key Metrics

Create a script to extract important metrics:
````bash
cat > scripts/analyze-chaos-results.sh <<'SCRIPT'
#!/bin/bash

echo "=== Chaos Experiment Results Analysis ==="
echo ""

# Function to analyze a chaos result
analyze_result() {
  RESULT_NAME=$1
  EXPERIMENT_TYPE=$2
  
  echo "### $EXPERIMENT_TYPE Experiment"
  echo ""
  
  # Get verdict
  VERDICT=$(kubectl get chaosresult $RESULT_NAME -n default -o jsonpath='{.status.experimentStatus.verdict}' 2>/dev/null || echo "Not Found")
  echo "Verdict: $VERDICT"
  
  # Get probe success percentage
  PROBE_SUCCESS=$(kubectl get chaosresult $RESULT_NAME -n default -o jsonpath='{.status.experimentStatus.probeSuccessPercentage}' 2>/dev/null || echo "N/A")
  echo "Probe Success Rate: $PROBE_SUCCESS%"
  
  # Get phase
  PHASE=$(kubectl get chaosresult $RESULT_NAME -n default -o jsonpath='{.status.experimentStatus.phase}' 2>/dev/null || echo "Unknown")
  echo "Phase: $PHASE"
  
  # Get failure step (if failed)
  FAIL_STEP=$(kubectl get chaosresult $RESULT_NAME -n default -o jsonpath='{.status.experimentStatus.failStep}' 2>/dev/null)
  if [ -n "$FAIL_STEP" ]; then
    echo "Failure Step: $FAIL_STEP"
  fi
  
  echo ""
}

# Analyze both experiments
analyze_result "pod-delete-observable-pod-delete" "Pod Delete"
analyze_result "cpu-stress-chaos-pod-cpu-hog" "CPU Stress"

echo "=== Target Application Status ==="
kubectl get pods -l app=chaos-target-app -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp

echo ""
echo "=== Chaos Infrastructure ==="
kubectl get chaosengine -n default
SCRIPT

chmod +x scripts/analyze-chaos-results.sh
./scripts/analyze-chaos-results.sh
````

### Examine Probe Results

Probes are the automated health checks that ran during chaos. Extract probe data:
````bash
# Get probe results from pod delete experiment
kubectl get chaosresult pod-delete-observable-pod-delete -n default -o jsonpath='{.status.probeStatuses}' | jq '.'

# Get probe results from CPU stress experiment
kubectl get chaosresult cpu-stress-chaos-pod-cpu-hog -n default -o jsonpath='{.status.probeStatuses}' | jq '.'
````

**If jq is not available:**
````bash
kubectl get chaosresult pod-delete-observable-pod-delete -n default -o yaml | grep -A 50 "probeStatuses:"
````

### Calculate Automated MTTR

For experiments that test recovery, calculate precise MTTR:
````bash
# Get experiment start and end times
kubectl get chaosresult pod-delete-observable-pod-delete -n default -o jsonpath='{.status.history}' | jq '.'
````

Unlike manual measurement with stopwatches (±2-5 second variance), automated measurement provides:
- Millisecond-precise timestamps
- Continuous probe data points
- Structured, queryable results
- Historical trend capability

### View Detailed Experiment Logs
````bash
# Get chaos runner logs
kubectl logs -n default pod-delete-observable-runner | tail -50

# Get experiment job logs
EXPERIMENT_POD=$(kubectl get pods -n default -l job-name --no-headers | grep pod-delete | head -1 | awk '{print $1}')
kubectl logs -n default $EXPERIMENT_POD
````

### Document Results
````bash
cat > reports/automated-chaos-results.md <<EOF
# Automated Chaos Results - Track 2

## Experiment Configuration

### Pod Delete Chaos
- **Duration:** 90 seconds
- **Interval:** 10 seconds (pod deleted every 10s)
- **Target:** 33% of pods (1 of 3)
- **Probes:** HTTP availability check (continuous)

### CPU Stress Chaos
- **Duration:** 120 seconds
- **CPU Cores:** 1 core at 100% load
- **Target:** 33% of pods (1 of 3)
- **Probes:** HTTP availability + pod status check

## Automated Measurements

### Pod Delete Results
- **Verdict:** $(kubectl get chaosresult pod-delete-observable-pod-delete -n default -o jsonpath='{.status.experimentStatus.verdict}' 2>/dev/null || echo "Check manually")
- **Probe Success Rate:** $(kubectl get chaosresult pod-delete-observable-pod-delete -n default -o jsonpath='{.status.experimentStatus.probeSuccessPercentage}' 2>/dev/null || echo "N/A")%

### CPU Stress Results
- **Verdict:** $(kubectl get chaosresult cpu-stress-chaos-pod-cpu-hog -n default -o jsonpath='{.status.experimentStatus.verdict}' 2>/dev/null || echo "Check manually")
- **Probe Success Rate:** $(kubectl get chaosresult cpu-stress-chaos-pod-cpu-hog -n default -o jsonpath='{.status.experimentStatus.probeSuccessPercentage}' 2>/dev/null || echo "N/A")%

## System Behavior During Chaos

### Pod Lifecycle
- Pods were deleted and recreated automatically by ReplicaSet
- No manual intervention required
- Recovery time: ~10-15 seconds per pod

### Service Availability
- Service remained available throughout both experiments
- HTTP probes confirmed continuous responsiveness
- Load balanced across healthy pods

### Resource Consumption
- CPU stress applied to single pod successfully
- Resource limits prevented complete exhaustion
- Other pods continued serving traffic normally

## Key Insights

### Automated vs Manual Comparison

**Measurement Precision:**
- Manual: ±2-5 second variance due to human timing
- Automated: Millisecond-accurate timestamps

**Reproducibility:**
- Manual: Variable conditions each run
- Automated: Identical YAML definition guarantees consistency

**Operational Overhead:**
- Manual: ~30-40 minutes active engineer time
- Automated: ~5 minutes to review results (zero execution time)

**Data Quality:**
- Manual: Single start/end measurement
- Automated: Continuous probe data throughout experiment

## Recommendations

1. **Version control chaos experiments** - Store YAML in Git for change tracking
2. **Schedule regular execution** - Run experiments weekly via CronJob
3. **Integrate with CI/CD** - Add chaos gates to deployment pipelines
4. **Expand probe coverage** - Add Prometheus metrics probes for deeper validation
5. **Automate result analysis** - Parse ChaosResult in scripts for trend analysis

---
**Experiment Date:** $(date)
**Platform:** LitmusChaos v3.0.0 (YAML-based, no Portal)
**Cluster:** $(kubectl config current-context)
EOF

cat reports/automated-chaos-results.md
````

---

## Exercise 5: Compare with Manual Approach

Create a direct comparison between your Track 1 manual chaos and Track 2 automated chaos experiences.

### Create Comparison Document
````bash
cat > reports/manual-vs-automated-comparison.md <<'EOF'
# Manual vs Automated Chaos Engineering Comparison

## Overview

This document compares the manual chaos approach from Track 1 against the automated YAML-based approach from Track 2.

## Execution Method

### Track 1: Manual Chaos
**How it worked:**
- Opened 3 terminals for monitoring
- Manually executed `kubectl delete pod` commands
- Used shell scripts with sleep timers
- Measured MTTR with stopwatch/date commands
- Documented results in markdown manually

**Time investment:**
- Setup monitoring: 5 minutes
- Execute chaos: 5 minutes
- Execute rollback: 5 minutes
- Document results: 15 minutes
- **Total: 30 minutes active time**

### Track 2: Automated Chaos
**How it worked:**
- Created ChaosEngine YAML definition
- Applied with `kubectl apply -f`
- LitmusChaos operator handled execution
- Automated probes validated behavior
- ChaosResult auto-generated with metrics

**Time investment:**
- Create YAML definition: 10 minutes (one-time)
- Apply experiment: 30 seconds
- Wait for completion: 0 minutes (unattended)
- Review results: 5 minutes
- **Total: 5 minutes active time (after initial setup)**

## Measurement Quality

### Track 1: Manual Measurement
**Method:**
```bash
echo "Start: $(date '+%H:%M:%S')"
kubectl rollout undo deployment/chaos-target-app
kubectl rollout status deployment/chaos-target-app
echo "End: $(date '+%H:%M:%S')"
# Calculate difference manually
```

**Accuracy:** ±2-5 seconds
- Human reaction time starting timer
- Human reaction time stopping timer
- Command execution delays
- Single point measurement (start/end only)

**Example MTTR:** 42 seconds ±5 seconds

### Track 2: Automated Measurement
**Method:**
```yaml
probe:
  - name: check-availability
    type: httpProbe
    mode: Continuous
    runProperties:
      interval: '5'  # Check every 5 seconds
```

**Accuracy:** ±1 millisecond
- Platform timestamps chaos injection
- Continuous probe data (every 5 seconds)
- Precise recovery detection
- Structured, queryable results

**Example Results:**
- Total checks: 24
- Successful: 23
- Failed: 1
- Success rate: 95.8%

## Reproducibility

### Track 1: Manual Reproducibility Challenges

**Variable factors:**
- Command timing (human typing speed)
- Cluster state at execution time
- Engineer attention/distractions
- Different engineers execute differently

**Example:** Running same experiment twice:
- Run 1: MTTR 38 seconds
- Run 2: MTTR 47 seconds
- Variance: 9 seconds (23%)

**Why?** Image cached in Run 1, not cached in Run 2.

### Track 2: Automated Reproducibility

**Controlled factors:**
```yaml
# Exact same YAML every execution
experiments:
  - name: pod-delete
    spec:
      components:
        env:
          - name: TOTAL_CHAOS_DURATION
            value: '90'  # Always 90 seconds
          - name: CHAOS_INTERVAL
            value: '10'  # Always 10 seconds
```

**Example:** Running same ChaosEngine twice:
- Run 1: 24 checks, 23 successful (95.8%)
- Run 2: 24 checks, 23 successful (95.8%)
- Variance: Minimal (conditions identical)

## Success Criteria

### Track 1: Implicit Criteria

**How success was determined:**
- "All pods show Running status"
- "curl returns 200 OK"
- "That looked fast enough"
- Engineer subjective judgment

**Problems:**
- Not defined before execution
- Varies by person and context
- Difficult to dispute objectively
- Cannot automate pass/fail

### Track 2: Explicit Criteria

**How success was defined:**
```yaml
probe:
  - name: check-availability
    httpProbe/inputs:
      method:
        get:
          criteria: ==
          responseCode: "200"  # Must return 200
    runProperties:
      interval: '5'             # Check every 5 seconds
```

**Benefits:**
- Defined before experiment runs
- Objective, measurable
- Automated verdict (Pass/Fail)
- Team alignment on "good"

## Operational Overhead

### Scaling Manual Chaos

**1 service, weekly testing:**
- Time: 30 minutes/week
- Feasible: Yes

**10 services, weekly testing:**
- Time: 300 minutes/week (5 hours)
- Feasible: Challenging

**10 services, daily testing:**
- Time: 2,100 minutes/week (35 hours)
- Feasible: No

### Scaling Automated Chaos

**1 service, weekly testing:**
- Setup: 10 minutes (one-time)
- Weekly review: 5 minutes
- Feasible: Yes

**10 services, weekly testing:**
- Setup: 100 minutes (one-time)
- Weekly review: 50 minutes
- Feasible: Yes

**10 services, daily testing:**
- Setup: 100 minutes (one-time)
- Daily review: ~10 minutes/day (70 min/week)
- Feasible: Yes

**With CronJob scheduling:**
- Review only failures (alerts)
- Time investment: <1 hour/week regardless of test count

## Data Retention and Sharing

### Track 1: Manual Documentation

**Storage:**
- Terminal output (lost after session)
- Manual notes in markdown
- Screenshots (if remembered)
- Verbal discussions in meetings

**Sharing:**
- Copy/paste into Slack
- Attach markdown to tickets
- Present in meetings
- Difficult to compare across time

### Track 2: Automated Documentation

**Storage:**
```bash
kubectl get chaosresult -n default
# Stored as Kubernetes resources
# Queryable via kubectl/API
# Exportable as JSON/YAML
```

**Sharing:**
- Query ChaosResult programmatically
- Export structured data
- Build dashboards (Grafana)
- Historical trend analysis

**Example query:**
```bash
# Get all experiments from last week
kubectl get chaosresult -n default \
  --selector=experiment=pod-delete \
  -o json | jq '.items[].status.experimentStatus.verdict'
```

## Infrastructure as Code

### Track 1: Procedural Approach

**Documentation:**
```markdown
1. Open terminal
2. Run: kubectl delete pod <name>
3. Watch pods recover
4. Record time
```

**Problems:**
- Steps must be executed manually
- No version control for process
- Changes not tracked
- Cannot code-review chaos

### Track 2: Declarative Approach

**Definition:**
```yaml
# chaos-experiments/pod-delete.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: pod-delete-chaos
spec:
  # ... experiment definition
```

**Benefits:**
- Version controlled in Git
- Code review chaos changes
- Rollback experiment changes
- Track experiment evolution

**Example Git workflow:**
```bash
# Create experiment
git add chaos-experiments/pod-delete.yaml
git commit -m "Add pod deletion chaos for app X"

# Modify experiment
# ... edit YAML ...
git commit -m "Increase chaos duration to 120s"

# Revert if needed
git revert HEAD
```

## Cost-Benefit Analysis

### Manual Chaos ROI

**Investment:** Zero tooling cost, just engineer time

**Cost per test:** 30 minutes × $75/hr = $37.50

**Annual cost (weekly testing, 10 services):**
- 52 weeks × 10 services × 30 min = 260 hours
- 260 hours × $75/hr = $19,500

### Automated Chaos ROI

**Investment:** 
- Initial setup: 100 minutes × $75/hr = $125
- YAML creation: 10 services × 10 min = 100 min = $125
- **Total: $250**

**Cost per test:** 5 minutes × $75/hr = $6.25

**Annual cost (weekly testing, 10 services):**
- Setup: $250 (one-time)
- Reviews: 52 weeks × 50 min = 43.3 hours × $75/hr = $3,248
- **Total: $3,498**

**Annual savings:** $19,500 - $3,498 = $16,002 (82% reduction)

**Break-even point:**
````
$250 / ($37.50 - $6.25) = 8 tests
````

Automation pays for itself after 8 experiments.

## When to Use Each Approach

### Use Manual Chaos When:
- ✅ Learning Kubernetes self-healing fundamentals
- ✅ Exploring new failure modes interactively
- ✅ Debugging specific incident scenarios
- ✅ One-off experiments (<5 total)
- ✅ Immediate investigation needed

### Use Automated Chaos When:
- ✅ Regular resilience validation (weekly/daily)
- ✅ CI/CD pipeline integration
- ✅ Multiple services need testing
- ✅ Trend analysis required
- ✅ Compliance/audit requirements
- ✅ Scaling beyond 10 tests/month

## Conclusion

**Manual chaos** is essential for learning and exploration. It builds intuition about system behavior and teaches fundamental Kubernetes resilience concepts.

**Automated chaos** is essential for systematic resilience programs. It scales efficiently, provides precise measurements, and enables data-driven reliability improvements.

**Best practice:** Start with manual chaos to learn, transition to automated chaos for ongoing validation.

---
**Analysis Date:** $(date)
**Engineer:** [Your name]
**Methodology:** Direct comparison of Track 1 and Track 2 results
EOF

cat reports/manual-vs-automated-comparison.md
````

### Commit Your Results
````bash
# Add all reports
git add reports/

# Commit with summary
git commit -m "Track 2 complete: Automated chaos via YAML

Experiments executed:
- Pod delete chaos: 90s duration, 10s intervals
- CPU stress chaos: 120s duration, 1 core at 100%

Results:
- Both experiments completed successfully
- ChaosResults generated automatically
- Probes validated continuous availability
- Zero manual intervention during execution

Key findings:
- YAML-based chaos provides millisecond precision
- Automated probes eliminate human measurement error
- Infrastructure as Code enables version control
- Operational overhead reduced by 80%+ vs manual"

# Push to repository
git push origin main
````

---

## Reflection Questions

Reflect on the automated chaos experience and compare it with manual approaches:

### Technical Reflection

1. **How did YAML-defined chaos differ from kubectl commands?** Which approach gave you better understanding of what was happening?

2. **What did continuous probes reveal** that manual curl loops couldn't capture?

3. **How would you modify the CPU stress experiment** to make it more challenging or realistic?

4. **What happens if you set `PODS_AFFECTED_PERC` to `100`?** Would that be safe in production?

### Operational Reflection

5. **Could you run these experiments daily** without disrupting your work? What about hourly?

6. **How would you integrate ChaosEngine YAML** into your CI/CD pipeline?

7. **What happens if probe success rate drops** from 100% to 70% over several weeks?

8. **How does Infrastructure as Code for chaos** change team collaboration compared to manual runbooks?

### Strategic Reflection

9. **When would you still choose manual chaos** even with automated YAML available?

10. **How would you convince a skeptical teammate** that YAML-based chaos is better than Portal UI?

11. **What additional chaos scenarios** would you add to comprehensively test your application?

12. **How does version-controlling chaos experiments** enable better reliability practices?

---

## Troubleshooting

### ChaosEngine Stuck in "Initialized" State

**Symptoms:**
````bash
kubectl get chaosengine my-chaos -n default
````
Shows status never progresses beyond "Initialized".

**Diagnosis:**
````bash
# Check if runner pod was created
kubectl get pods -n default | grep runner

# Check operator logs
kubectl logs -n litmus -l app.kubernetes.io/component=operator --tail=50
````

**Resolution:**

Check RBAC permissions:
````bash
kubectl get sa litmus-admin -n default
kubectl auth can-i '*' '*' --as=system:serviceaccount:default:litmus-admin
````

If permissions are missing, reapply:
````bash
kubectl apply -f chaos-experiments/litmus-rbac.yaml
````

---

### Probe Failures Despite Service Being Available

**Symptoms:**
ChaosResult shows probe failures but manual curl succeeds.

**Diagnosis:**
````bash
# Get probe details
kubectl get chaosresult <name> -n default -o yaml | grep -A 20 probeStatus
````

**Cause:**
Probe timeout too aggressive for service response time under load.

**Resolution:**

Edit experiment YAML and increase timeout:
````yaml
probe:
  - name: check-availability
    runProperties:
      probeTimeout: '10'  # Increase from 5 to 10 seconds
      retry: 5            # Increase retries
````

Delete old ChaosEngine and reapply:
````bash
kubectl delete chaosengine <name> -n default
kubectl apply -f chaos-experiments/<experiment>.yaml
````

---

### No Pods Affected by Chaos

**Symptoms:**
Chaos completes but no pods were actually stressed or deleted.

**Diagnosis:**
````bash
# Check experiment logs
kubectl logs -n default -l name=<experiment-name>
````

Look for: "0 pods selected for chaos"

**Cause:**
Label selector doesn't match any pods.

**Resolution:**

Verify label selector matches target pods:
````bash
# Check experiment selector
kubectl get chaosengine <name> -n default -o yaml | grep -A 5 appinfo

# Check actual pod labels
kubectl get pods -l app=chaos-target-app --show-labels
````

Update `applabel` in experiment YAML to match pod labels exactly.

---

### ChaosResult Not Created

**Symptoms:**
````bash
kubectl get chaosresult -n default
````
Returns no results after experiment completes.

**Diagnosis:**
````bash
# Check chaos engine status
kubectl get chaosengine <name> -n default -o yaml | grep -A 10 status
````

**Cause:**
Experiment failed before creating result, or `jobCleanUpPolicy` is `delete`.

**Resolution:**

Change cleanup policy to retain results:
````yaml
spec:
  jobCleanUpPolicy: 'retain'  # Keep resources after completion
````

Check experiment pod logs:
````bash
kubectl logs -n default <experiment-pod-name>
````

---

## Next Steps

You've completed automated chaos engineering using YAML-based ChaosEngine definitions. You've experienced how Infrastructure as Code principles apply to resilience testing, enabling version control, reproducibility, and scalability that manual approaches cannot achieve.

**Proceed to the final phase** to synthesize your learnings:

[Final Phase: Comparative Analysis & Cleanup](final-phase-analysis.md)

In the final phase, you'll:
- Generate comprehensive comparison report
- Calculate operational ROI of automation
- Document lessons learned
- Clean up lab infrastructure
- Create production implementation roadmap

**Key takeaway:** Manual chaos teaches you HOW systems fail. Automated chaos VALIDATES that they recover reliably. YAML-based chaos is Infrastructure as Code—version controlled, reviewable, and scalable.