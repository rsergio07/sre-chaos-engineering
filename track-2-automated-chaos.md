# Track 2: Scheduled Resilience Testing (Automated Chaos)

## Table of Contents

- [Overview](#overview)
- [Learning Objectives](#learning-objectives)
- [Scenario Context](#scenario-context)
- [Exercise 1: Explore LitmusChaos Portal](#exercise-1-explore-litmuschaos-portal)
- [Exercise 2: Design CPU Stress Experiment](#exercise-2-design-cpu-stress-experiment)
- [Exercise 3: Execute Automated Chaos](#exercise-3-execute-automated-chaos)
- [Exercise 4: Analyze Automated Results](#exercise-4-analyze-automated-results)
- [Exercise 5: Compare with Manual Approach](#exercise-5-compare-with-manual-approach)
- [Reflection Questions](#reflection-questions)
- [Troubleshooting](#troubleshooting)

---

## Overview

This track demonstrates the evolution from reactive incident response to proactive resilience validation. Instead of waiting for production failures and manually measuring recovery, you'll design automated chaos experiments that run on schedules, define success criteria in advance, and measure outcomes automatically. This represents how mature SRE teams systematically test resilience before incidents impact customers.

Unlike Track 1's manual approach where you executed commands and used stopwatches, automated chaos engineering uses declarative workflows. You define what failure to inject, what success looks like, and when to run the test. The platform handles execution, measurement, and reporting without requiring real-time human monitoring.

**Expected Time:** 30-40 minutes

**What You'll Learn:**
- LitmusChaos Portal navigation and workflow design
- Hypothesis-driven experiment creation
- Automated MTTR measurement and resilience scoring
- Chaos scheduling for regular validation
- Production-grade chaos engineering practices

---

## Learning Objectives

By completing this track, you will:

1. Navigate the LitmusChaos Portal interface to understand how production chaos platforms organize experiments, workflows, and results.

2. Design a CPU stress chaos experiment using visual workflow builders, defining target selection, fault parameters, and execution timing.

3. Establish hypothesis-driven success criteria that specify measurable expectations for system behavior under chaos conditions.

4. Execute automated chaos workflows that inject faults, measure recovery metrics, and generate pass/fail reports without manual intervention.

5. Analyze automated resilience scores and detailed experiment logs to understand system behavior under resource exhaustion scenarios.

6. Compare automated MTTR measurements against manual baseline measurements to quantify the benefits of chaos automation.

---

## Scenario Context

**Time:** Monday morning, weekly SRE team meeting  
**Discussion:** Last Friday's incident review  
**Decision:** Implement proactive chaos testing  
**Your Task:** Design automated resilience validation that runs every Friday afternoon

Your team reviewed Friday's rollback incident and recognized a pattern: most production issues occur during Friday afternoon deployments when the team is least prepared for weekend on-call. Your manager asks, "How can we test our rollback procedures every Friday without causing actual outages?"

This is where automated chaos engineering provides the answer. You'll design a scheduled experiment that validates system resilience predictably, safely, and without requiring engineer intervention. The experiment runs automatically, measures recovery metrics, and alerts the team only if success criteria aren't met.

---

## Exercise 1: Explore LitmusChaos Portal

Before designing experiments, familiarize yourself with the LitmusChaos Portal interface and understand how it organizes chaos engineering workflows.

### Access the Portal

If you closed the Portal earlier, reopen it:

```bash
# Get Portal URL
minikube service chaos-litmus-frontend-service -n litmus --url
```

Copy the displayed URL and open it in your browser, or use:

```bash
# Open Portal automatically
minikube service chaos-litmus-frontend-service -n litmus
```

### Login to ChaosCenter

**Default credentials:**
- **Username:** `admin`
- **Password:** `litmus`

After login, you'll see the ChaosCenter dashboard.

### Navigate the Dashboard

The main dashboard displays several key sections:

**1. Overview Panel (Top)**
- Shows cluster connection status
- Displays total workflows created
- Shows recent experiment activity
- Resilience score trends

**2. Workflows Tab (Left Sidebar)**
- Lists all chaos workflows (experiments)
- Shows workflow status (Running, Completed, Failed)
- Provides access to workflow creation wizard

**3. ChaosHubs Tab**
- Contains pre-built chaos experiment templates
- Organized by fault category (pod, node, network, etc.)
- Each experiment is customizable

**4. Analytics Tab**
- Historical resilience scores
- Trend analysis across multiple runs
- Comparison graphs for different workflows

**5. Settings Tab**
- User management
- Agent configuration
- Integration settings

### Explore Available Chaos Experiments

Click on **"ChaosHubs"** in the left sidebar to see available experiments:

1. Click **"Litmus ChaosHub"** (the default hub)
2. Browse the experiment categories:
   - **Generic:** Pod delete, pod network loss, container kill
   - **Kubernetes:** Node drain, node CPU hog, pod CPU hog
   - **AWS/GCP/Azure:** Cloud-specific experiments

**Key experiments you'll see:**
- `pod-delete` - Kills target pods
- `pod-cpu-hog` - Stresses CPU on target pods
- `pod-memory-hog` - Exhausts memory on target pods
- `pod-network-latency` - Injects network delay

Each experiment has:
- **Description:** What the fault does
- **Parameters:** Configurable settings (duration, intensity)
- **Prerequisites:** Required permissions or configurations

### Understand Workflow Concepts

LitmusChaos uses several key concepts:

**Workflow:** A sequence of one or more chaos experiments that execute together. Workflows can include:
- Serial execution (one experiment after another)
- Parallel execution (multiple experiments simultaneously)
- Conditional logic (run experiment B only if experiment A succeeds)

**ChaosEngine:** The execution specification that defines:
- Which experiment to run
- Which pods to target (using label selectors)
- Fault parameters (duration, intensity)
- Success criteria (probes and checks)

**ChaosResult:** The outcome record containing:
- Experiment verdict (Pass/Fail)
- Detailed logs and events
- Measured metrics (MTTR, downtime, error rates)
- Probe results

**Probes:** Health checks that validate system behavior:
- **HTTP Probe:** Tests endpoint availability
- **Command Probe:** Executes kubectl commands
- **Prometheus Probe:** Queries metrics
- **Kubernetes Probe:** Checks resource states

---

## Exercise 2: Design CPU Stress Experiment

Now create an automated chaos workflow that tests system resilience under CPU resource exhaustion. This experiment is more complex than simple pod deletion and better represents realistic production stress.

### Understand CPU Stress Chaos

CPU stress chaos simulates scenarios like:
- Application code entering infinite loops
- Batch jobs consuming excessive CPU
- Resource limits misconfigured
- Multiple processes competing for CPU

Unlike pod deletion (instant failure), CPU stress is gradual degradation. The system remains partially functional but slowed. This tests whether:
- Resource limits prevent complete exhaustion
- Health checks detect degraded performance
- Kubernetes throttles rather than kills pods
- Service remains responsive under load

### Create New Workflow

In the LitmusChaos Portal:

1. Click **"Workflows"** in the left sidebar
2. Click **"Schedule a workflow"** button
3. Select workflow creation method:
   - Choose **"Create a new workflow using the experiments from ChaosHubs"**
4. Click **"Next"**

### Configure Workflow Basics

**Step 1: Workflow Settings**

Fill in the workflow details:

- **Workflow Name:** `cpu-stress-rollback-test`
- **Workflow Description:** `Validates rollback under CPU resource exhaustion`
- **Target Agent:** Select `Self-Agent` (the agent in litmus namespace)

Click **"Next"**

### Add CPU Stress Experiment

**Step 2: Tune Workflow**

Now you'll add the chaos experiment to your workflow:

1. In the workflow canvas, you'll see a starting point node
2. Click the **"+"** button to add an experiment
3. Search for experiments: Type `pod-cpu-hog` in the search box
4. Click on **"pod-cpu-hog"** to add it to the workflow
5. Click **"Next"** to proceed to experiment configuration

### Configure CPU Stress Parameters

**Step 3: Experiment Configuration**

Now configure the CPU stress experiment parameters:

**Target Application Settings:**
- **Application Namespace:** `default`
- **Application Label:** `app=chaos-target-app`
- **Application Kind:** `deployment`

These settings tell LitmusChaos which pods to target using label selectors.

**Chaos Parameters:**
- **CPU Cores:** `1` (stress one CPU core)
- **Total Chaos Duration:** `120` seconds (2 minutes of stress)
- **Chaos Interval:** `10` seconds (check interval)
- **Pods Affected Percentage:** `33` (affect 1 of 3 pods)

**Chaos Library Configuration:**
- **Sequence:** `serial` (one pod at a time)
- **LIB Image:** Leave default

**Probe Configuration:**

Add a health probe to verify service availability during chaos:

1. Click **"Add Probe"**
2. Select **"HTTP Probe"**
3. Configure probe:
   - **Probe Name:** `service-availability-check`
   - **Type:** `Continuous`
   - **URL:** `http://chaos-target-service.default.svc.cluster.local:80`
   - **Method:** `GET`
   - **Criteria:** `==`
   - **Response Code:** `200`
   - **Run Properties:**
     - **Interval:** `5s`
     - **Timeout:** `2s`
     - **Retry:** `3`

This probe checks service availability every 5 seconds during the chaos period.

4. Click **"Add Probe"** to save

### Define Success Criteria

Still in the experiment configuration:

**Steady State Hypothesis:**

Add a description of expected behavior:
```
The application should maintain service availability during CPU stress.
At least 2 of 3 pods should remain responsive.
Service endpoints should return HTTP 200 for >90% of probe checks.
No pod should be terminated or restarted due to CPU exhaustion.
```

**Expected Outcome:**
- Resilience score: >80%
- Service availability: >90%
- Pod restart count: 0

Click **"Next"** when configuration is complete.

### Schedule the Workflow

**Step 4: Scheduling**

Configure when the workflow should run:

**Execution Mode:**
- Select **"Scheduled workflow"**

**Schedule Settings:**
- **Schedule Type:** `Recurring`
- **Cron Expression:** `0 15 * * 5`
  
This cron expression means: "At 15:00 (3 PM) on Friday every week"

**Or for immediate testing:**
- Select **"Run once now"** instead

For this lab, select **"Run once now"** so we can observe results immediately.

Click **"Next"**

### Review and Create

**Step 5: Verify and Commit**

Review the workflow configuration summary:
- Workflow name and description
- Target application (default namespace, app=chaos-target-app)
- Experiment type (pod-cpu-hog)
- Chaos duration (120 seconds)
- Probe configuration (HTTP availability check)
- Schedule (immediate execution for lab)

Click **"Finish"** to create the workflow.

### Verify Workflow Creation

After creation, you'll be redirected to the workflows list:

```bash
# Verify workflow was created (from terminal)
kubectl get workflows -n litmus
kubectl get chaosengines -n litmus
```

**Expected output:**
```
NAME                        AGE
cpu-stress-rollback-test    30s

NAME                           STATUS    AGE
cpu-stress-rollback-test-1     Running   20s
```

The workflow is now prepared and will execute according to schedule.

---

## Exercise 3: Execute Automated Chaos

Now observe the automated chaos execution. Unlike Track 1 where you manually triggered actions, the LitmusChaos platform handles everything automatically.

### Monitor Workflow Execution in Portal

In the LitmusChaos Portal:

1. Navigate to **"Workflows"** tab
2. Click on your workflow: **"cpu-stress-rollback-test"**
3. You'll see the workflow visualization with real-time status

**Workflow Stages:**
- **Install Experiments:** Portal deploys experiment resources
- **Execute Chaos:** Platform injects CPU stress fault
- **Probes Running:** HTTP availability checks execute continuously
- **Collect Results:** Platform gathers metrics and logs
- **Cleanup:** Removes chaos infrastructure

### Observe in Kubernetes Dashboard

Open the Kubernetes Dashboard if not already open:

```bash
minikube dashboard &
```

Navigate to:
1. **Workloads** → **Pods**
2. Filter by namespace: `default`
3. Watch the `chaos-target-app` pods

You'll see:
- One pod showing increased CPU usage (if metrics-server displays it)
- CPU stress experiment pod appears in default namespace
- Original pods remain Running (not terminated)

### Monitor from Command Line

Open a terminal and watch chaos execution:

```bash
# Watch chaos engine status
kubectl get chaosengines -n litmus -w
```

**Expected progression:**
```
NAME                           STATUS              AGE
cpu-stress-rollback-test-1     Initialized         10s
cpu-stress-rollback-test-1     Running             15s
cpu-stress-rollback-test-1     Completed           145s
```

In another terminal, watch target pods:

```bash
# Watch target application pods
kubectl get pods -l app=chaos-target-app -w
```

**Expected output:**
```
NAME                                READY   STATUS    RESTARTS   AGE
chaos-target-app-xxxxx-aaaaa        1/1     Running   0          20m
chaos-target-app-xxxxx-bbbbb        1/1     Running   0          20m
chaos-target-app-xxxxx-ccccc        1/1     Running   0          20m
```

Pods should remain Running throughout chaos (no restarts expected with proper resource limits).

### Check Chaos Experiment Pod

During execution, LitmusChaos creates helper pods:

```bash
# View chaos experiment pods
kubectl get pods -l chaosUID -n default
```

**Expected output:**
```
NAME                        READY   STATUS    RESTARTS   AGE
pod-cpu-hog-xxxxx           1/1     Running   0          30s
```

This pod runs the CPU stress tool against the target pod.

### Monitor Service Availability

Test service availability during chaos:

```bash
# Ensure port-forward is running
kubectl port-forward svc/chaos-target-service 8080:80 --address 0.0.0.0 &

# Test service during chaos
for i in {1..20}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
  echo "$(date '+%H:%M:%S') - HTTP $STATUS"
  sleep 5
done
```

**Expected output:**
```
15:15:10 - HTTP 200
15:15:15 - HTTP 200
15:15:20 - HTTP 200  ← Chaos starts
15:15:25 - HTTP 200  ← CPU stressed but service responds
15:15:30 - HTTP 200
...
15:17:20 - HTTP 200  ← Chaos ends
15:17:25 - HTTP 200
```

Service should remain available throughout because:
- Only 1 of 3 pods is stressed
- Resource limits prevent complete CPU monopolization
- Other 2 pods continue serving traffic

### Wait for Chaos Completion

The experiment runs for 120 seconds. Wait for completion:

```bash
# Check chaos engine final status
kubectl get chaosengine cpu-stress-rollback-test-1 -n litmus -o jsonpath='{.status.engineStatus}'
echo ""
```

**Expected output:**
```
completed
```

Or in the Portal, workflow status changes from **"Running"** to **"Completed"**.

---

## Exercise 4: Analyze Automated Results

Now examine the automated measurements, resilience scores, and detailed logs that the platform collected without manual intervention.

### View Workflow Results in Portal

In the LitmusChaos Portal:

1. Go to **"Workflows"** tab
2. Click on **"cpu-stress-rollback-test"**
3. Click on the completed workflow run (shows timestamp)

**Results Dashboard Shows:**

**Resilience Score:** A percentage (0-100%) calculated from:
- Probe success rate
- Experiment verdict (pass/fail)
- System stability during chaos

**Example:** 95% resilience score means the system met 95% of defined success criteria.

**Experiment Verdict:** 
- **Pass:** System met all success criteria
- **Fail:** System violated one or more criteria

**Probe Results:**
- HTTP availability check success rate
- Number of successful vs failed probes
- Response time measurements

### Examine Detailed Logs

Click on the experiment node in the workflow visualization:

1. Click **"Logs"** tab
2. Review experiment execution logs:
   ```
   [INFO] Starting pod-cpu-hog experiment
   [INFO] Target pods selected: chaos-target-app-xxxxx-aaaaa
   [INFO] Injecting CPU stress for 120 seconds
   [INFO] Monitoring probe: service-availability-check
   [INFO] Probe check 1/24: SUCCESS (HTTP 200, 45ms)
   [INFO] Probe check 2/24: SUCCESS (HTTP 200, 52ms)
   ...
   [INFO] CPU stress completed
   [INFO] Probe success rate: 24/24 (100%)
   [INFO] Experiment verdict: PASS
   ```

3. Click **"Chaos Result"** tab to see structured data

### Get Automated MTTR Measurement

The ChaosResult contains precise timing:

```bash
# Get chaos result details
kubectl get chaosresult cpu-stress-rollback-test-1-pod-cpu-hog -n litmus -o yaml
```

**Key fields in output:**

```yaml
status:
  experimentStatus:
    verdict: Pass
    probeSuccessPercentage: "100"
  history:
    passedRuns: 1
    failedRuns: 0
    targets:
    - name: chaos-target-app-xxxxx-aaaaa
      kind: pod
      chaosStatus: injected
```

**MTTR Calculation:**

For CPU stress, MTTR measures time from chaos end to system returning to normal:

```bash
# Check if any pods were restarted
kubectl get pods -l app=chaos-target-app -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount
```

**Expected output:**
```
NAME                                RESTARTS
chaos-target-app-xxxxx-aaaaa        0
chaos-target-app-xxxxx-bbbbb        0
chaos-target-app-xxxxx-ccccc        0
```

**MTTR for this scenario:** 0 seconds

The system never actually failed—it degraded under load but remained functional. This demonstrates successful resilience; the system handled the stress without requiring recovery.

### Compare Probe Data

Review HTTP probe statistics:

In the Portal's probe results section:
- **Total Checks:** 24 (120 seconds ÷ 5 second interval)
- **Successful:** 24
- **Failed:** 0
- **Success Rate:** 100%
- **Average Response Time:** ~50ms

### Calculate Resilience Score

LitmusChaos calculates resilience score as:

```
Resilience Score = (Probe Success Rate × Weight) + (Experiment Pass × Weight)

Example:
- Probe success: 100% × 0.5 = 50%
- Experiment pass: Yes (100%) × 0.5 = 50%
- Total: 100% resilience score
```

**Interpretation:**
- **90-100%:** Excellent resilience, system highly reliable
- **70-89%:** Good resilience, minor issues observed
- **50-69%:** Poor resilience, significant degradation
- **<50%:** Failed resilience, system critically impacted

### Document Automated Results

Create a results file:

```bash
cat > automated-chaos-results.md <<EOF
# Automated Chaos Results - Track 2

## Experiment Configuration
- **Workflow Name:** cpu-stress-rollback-test
- **Experiment Type:** pod-cpu-hog
- **Chaos Duration:** 120 seconds
- **Target:** 1 of 3 pods (33%)
- **CPU Stress:** 1 core at 100%

## Automated Measurements

### Resilience Score
- **Score:** [Check your Portal - e.g., 100%]
- **Verdict:** [Pass/Fail from Portal]
- **Probe Success Rate:** [e.g., 100%]

### MTTR Analysis
- **System Failure:** No (system remained operational)
- **Pod Restarts:** 0
- **Recovery Time:** 0 seconds (no recovery needed)
- **Service Disruption:** None detected

### Probe Results
- **Total HTTP Checks:** 24
- **Successful Checks:** [Your number from Portal]
- **Failed Checks:** [Your number from Portal]
- **Average Response Time:** [Your measurement from Portal]

## System Behavior During Chaos

### Pod Status
- Target pod remained Running throughout
- No pod restarts triggered
- Resource limits effectively prevented exhaustion

### Service Availability
- HTTP endpoints remained responsive
- All probe checks returned 200 status
- No request timeouts observed

### Resource Consumption
- CPU usage increased on target pod
- Memory remained stable
- Other pods unaffected

## Key Insights

### What Worked Well
- Resource limits prevented complete CPU monopolization
- Service remained available during single-pod stress
- Automated probes provided continuous validation
- No manual intervention required

### Automated vs Manual Comparison
- Measurement precision: Millisecond accuracy vs human timing
- Reproducibility: Exact conditions repeatable
- Operational overhead: Zero engineer time during execution
- Documentation: Automatic logs and metrics

---
**Experiment Completed:** $(date)
**Platform:** LitmusChaos v3.0.0
EOF

cat automated-chaos-results.md
```

---

## Exercise 5: Compare with Manual Approach

Now directly compare the automated chaos experience against your manual chaos baseline from Track 1.

### Comparison Matrix

Create a structured comparison:

```bash
cat > manual-vs-automated-comparison.md <<EOF
# Manual vs Automated Chaos Engineering Comparison

## Experiment Execution

| Aspect | Track 1 (Manual) | Track 2 (Automated) |
|--------|------------------|---------------------|
| **Chaos Type** | Pod deletion | CPU stress |
| **Trigger Method** | kubectl delete pod | Scheduled workflow |
| **Engineer Involvement** | Continuous (20-30 min) | Setup only (10 min) |
| **Reproducibility** | Variable conditions | Identical each run |
| **Documentation** | Manual notes | Automatic logs |

## MTTR Measurement

| Aspect | Track 1 (Manual) | Track 2 (Automated) |
|--------|------------------|---------------------|
| **Timing Method** | Stopwatch/date commands | Platform instrumentation |
| **Precision** | ±2-5 seconds | Millisecond accuracy |
| **Data Points** | Single measurement | Continuous metrics |
| **Human Error** | Possible | Eliminated |

### Track 1 Manual MTTR
- **Measured MTTR:** [Your Track 1 result, e.g., 42 seconds]
- **Measurement method:** Manual timing
- **Confidence level:** Moderate (human reaction time affects accuracy)

### Track 2 Automated MTTR
- **Measured MTTR:** 0 seconds (no failure occurred)
- **Measurement method:** Platform instrumentation
- **Confidence level:** High (millisecond precision)

**Note:** Direct MTTR comparison difficult because Track 1 tested rollback (recovery from failure) while Track 2 tested resilience (continued operation under stress).

## Success Criteria

| Aspect | Track 1 (Manual) | Track 2 (Automated) |
|--------|------------------|---------------------|
| **Defined When** | During/after incident | Before experiment |
| **Criteria Type** | Subjective ("looks good") | Objective (probe pass rates) |
| **Pass/Fail** | Engineer judgment | Automated verdict |
| **Validation** | Visual inspection | Continuous probes |

## Operational Overhead

### Track 1: Manual Approach
- **Prep time:** 5 minutes (setup monitoring)
- **Execution time:** 20-30 minutes (active monitoring required)
- **Analysis time:** 10-15 minutes (manual calculation and documentation)
- **Total engineer time:** ~40 minutes per test
- **Frequency limit:** Impractical to run daily (too much time)

### Track 2: Automated Approach
- **Prep time:** 10-15 minutes (one-time workflow creation)
- **Execution time:** 0 minutes (runs unattended)
- **Analysis time:** 5 minutes (review automated results)
- **Total engineer time:** ~5 minutes per subsequent run
- **Frequency limit:** Can run hourly with zero additional effort

**Scalability:** Manual approach requires 40 min × N tests. Automated requires 15 min setup + 5 min × N analyses.

## Reproducibility

### Track 1: Manual Challenges
- Timing variations in command execution
- Different cluster states between runs
- Human factors (attention, fatigue, interruptions)
- Difficult to replicate exact conditions

### Track 2: Automated Benefits
- Identical workflow definition each run
- Consistent target selection via label selectors
- Standardized probe configuration
- Version-controlled experiment definitions

## Observability

| Data Type | Track 1 (Manual) | Track 2 (Automated) |
|-----------|------------------|---------------------|
| **Pod states** | Terminal watch output | Structured logs |
| **Service availability** | Manual curl loop | Continuous HTTP probes |
| **Timing data** | Stopwatch/notes | Platform metrics |
| **Historical trends** | Not captured | Automatic database |
| **Sharing results** | Markdown files | Portal dashboards |

## When to Use Each Approach

### Use Manual Chaos When:
- Learning Kubernetes self-healing fundamentals
- Exploring new failure modes interactively
- Debugging specific incident scenarios
- Immediate investigation needed (no time for workflow setup)

### Use Automated Chaos When:
- Regular resilience validation (weekly/monthly)
- CI/CD pipeline integration
- Trend analysis over time required
- Scaling to multiple services/clusters
- Compliance or audit requirements
- Team needs reproducible evidence

## Cost-Benefit Analysis

### Manual Chaos
- **Benefit:** No additional tooling required
- **Cost:** High operational overhead per test
- **Best for:** One-off experiments, learning

### Automated Chaos
- **Benefit:** Scales to unlimited tests with minimal overhead
- **Cost:** Initial setup investment (tooling, workflow creation)
- **Best for:** Systematic resilience programs

## Recommendations

Based on this comparison:

1. **Start with manual chaos** to learn system behavior and validate basic resilience
2. **Transition to automated chaos** for regular, scheduled resilience testing
3. **Use both approaches** - manual for exploration, automated for validation
4. **Invest in automation** when running more than 5 tests per month per service

---
**Analysis Date:** $(date)
**Engineer:** [Your name]
EOF

cat manual-vs-automated-comparison.md
```

### Visualize the Differences

Create a summary graphic (ASCII art for terminal):

```bash
cat <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║           CHAOS ENGINEERING MATURITY PROGRESSION              ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  TRACK 1: MANUAL RESPONSE                                    ║
║  ┌─────────────────────────────────────────────────────┐    ║
║  │ Incident → Manual Investigation → Rollback → MTTR   │    ║
║  │  Occurs     (Engineer watches)     (kubectl)  (±5s) │    ║
║  └─────────────────────────────────────────────────────┘    ║
║  • Reactive                                                   ║
║  • Time-pressured decisions                                   ║
║  • Manual measurement                                         ║
║  • Imprecise MTTR                                            ║
║  • ~40 min engineer time per test                            ║
║                                                               ║
║  TRACK 2: AUTOMATED CHAOS                                    ║
║  ┌─────────────────────────────────────────────────────┐    ║
║  │ Schedule → Auto Execute → Probes → Resilience Score │    ║
║  │ (Friday)    (No human)     (Pass)   (100% ±0.001s)  │    ║
║  └─────────────────────────────────────────────────────┘    ║
║  • Proactive                                                  ║
║  • Hypothesis-driven                                          ║
║  • Automated measurement                                      ║
║  • Millisecond precision                                      ║
║  • ~5 min engineer time per test                             ║
║                                                               ║
║  KEY INSIGHT:                                                 ║
║  Manual chaos teaches HOW systems fail                        ║
║  Automated chaos VALIDATES they recover reliably              ║
╚═══════════════════════════════════════════════════════════════╝
EOF
```

### Commit Comparison Analysis

```bash
# Add all comparison documents
git add automated-chaos-results.md manual-vs-automated-comparison.md

# Commit with comprehensive message
git commit -m "Track 2 complete: Automated chaos with resilience scoring

- Created cpu-stress-rollback-test workflow in LitmusChaos Portal
- Executed automated CPU stress chaos (120s duration)
- Achieved 100% resilience score with 0s MTTR
- Compared manual vs automated approaches comprehensively
- Documented operational maturity differences"

# Push to repository
git push origin main
```

---

## Reflection Questions

Reflect on the automated chaos experience and compare it with manual approaches:

### Technical Reflection

1. **How did CPU stress differ from pod deletion?** Which better represents realistic production failures?

2. **Why was MTTR zero in this experiment?** Does this mean the chaos was ineffective, or does it demonstrate good resilience?

3. **What did the continuous probes reveal** that you couldn't observe with manual curl loops?

4. **How would you adjust the experiment** to make it more challenging or realistic?

### Operational Reflection

5. **Could you run this experiment every Friday** without disrupting your work? What about running it hourly?

6. **How would you share these results** with your engineering team? Is the Portal dashboard sufficient?

7. **What happens if the resilience score drops** from 100% to 70% over several weeks? How would you investigate?

8. **How does scheduling automation** change your relationship with chaos testing compared to manual on-demand testing?

### Strategic Reflection

9. **When would you still use manual chaos** even with automated platforms available?

10. **How many different services could you test** with automated chaos vs manual approaches?

11. **What role does automated chaos play** in CI/CD pipelines and deployment gates?

12. **How does hypothesis-driven testing** change how you think about system reliability?

---

## Troubleshooting

### Workflow Stuck in "Running" State

**Symptoms:**
Workflow shows Running status for more than 5 minutes beyond expected chaos duration.

**Diagnosis:**
```bash
# Check chaos engine status
kubectl get chaosengine -n litmus

# Check experiment pod logs
kubectl logs -n default -l chaosUID
```

**Resolution:**

If experiment pod shows errors:
```bash
# Delete stuck chaos engine
kubectl delete chaosengine <engine-name> -n litmus

# Recreate workflow in Portal
```

---

### Probe Failures Despite Service Being Available

**Symptoms:**
Portal shows probe failure rate >10% but manual curl tests succeed.

**Diagnosis:**

Check probe configuration:
```bash
# Get chaos result details
kubectl get chaosresult -n litmus -o yaml | grep -A 20 probeStatus
```

**Cause:**
Probe timeout too aggressive (e.g., 1s timeout when service needs 2s to respond under load).

**Resolution:**

Edit workflow in Portal:
1. Go to workflow configuration
2. Click on probe settings
3. Increase timeout from 2s to 5s
4. Increase retry from 3 to 5
5. Save and re-run workflow

---

### Target Pods Not Selected

**Symptoms:**
Chaos executes but no pods are stressed. Logs show "0 pods selected".

**Diagnosis:**
```bash
# Check experiment target configuration
kubectl get chaosengine <engine-name> -n litmus -o yaml | grep -A 10 appinfo

# Verify pod labels
kubectl get pods -l app=chaos-target-app --show-labels
```

**Cause:**
Label selector mismatch between experiment config and actual pods.

**Resolution:**

Update workflow target labels:
1. Edit workflow in Portal
2. Verify "Application Label" field matches pod labels exactly
3. Confirm namespace is "default"
4. Save and re-run

---

### Resilience Score Unexpectedly Low

**Symptoms:**
Resilience score <70% despite system appearing healthy.

**Diagnosis:**

Review probe results in Portal:
- Check which probes failed
- Review failure timestamps
- Examine probe logs

**Common causes:**
1. Network delays causing probe timeouts
2. Resource limits too restrictive
3. Health check probes interfering with chaos
4. Too many pods affected simultaneously

**Resolution:**

Adjust experiment parameters:
- Reduce pods affected percentage (33% → 20%)
- Increase probe timeout (2s → 5s)
- Reduce chaos duration (120s → 60s)
- Change sequence from parallel to serial

---

## Next Steps

You've now completed both manual and automated chaos engineering tracks. You've experienced reactive incident response and proactive resilience testing firsthand.

**Proceed to the final phase** to synthesize your learnings:

[Final Phase: Comparative Analysis & Cleanup](final-phase-analysis.md)

In the final phase, you'll:
- Generate a comprehensive comparison report
- Document operational maturity improvements
- Quantify the benefits of chaos automation
- Clean up all lab infrastructure
- Receive recommendations for implementing chaos in production

**Key takeaway:** Manual chaos teaches you HOW systems fail. Automated chaos VALIDATES that they recover reliably. Both approaches have value in a mature SRE practice.