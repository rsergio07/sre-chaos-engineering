# SRE Chaos Engineering Lab

## Table of Contents

- [Scenario: The Friday Afternoon Incident](#scenario-the-friday-afternoon-incident)
- [Why This Matters for SRE](#why-this-matters-for-sre)
- [Learning Objectives](#learning-objectives)
- [Prerequisites](#prerequisites)
- [Theoretical Foundation](#theoretical-foundation)
  - [Mean Time to Recovery (MTTR)](#mean-time-to-recovery-mttr)
  - [Manual Incident Response vs Automated Chaos](#manual-incident-response-vs-automated-chaos)
  - [Chaos Engineering Principles](#chaos-engineering-principles)
  - [LitmusChaos Architecture](#litmuschaos-architecture)
- [Lab Structure](#lab-structure)
  - [Phase 1: Environment Setup](#phase-1-environment-setup)
  - [Track 1: Emergency Rollback Drill (Manual Response)](#track-1-emergency-rollback-drill-manual-response)
  - [Track 2: Scheduled Resilience Testing (Automated Chaos)](#track-2-scheduled-resilience-testing-automated-chaos)
  - [Final Phase: Comparative Analysis & Cleanup](#final-phase-comparative-analysis--cleanup)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)
- [Additional Resources](#additional-resources)

---

## Scenario: The Friday Afternoon Incident

It's 3 PM on a Friday, and your team has just deployed a critical security patch to production. Within minutes, pods start crashing unexpectedly. Your monitoring dashboard lights up with alerts, and customer reports are flooding in. As the on-call SRE, you need to make a split-second decision: investigate the root cause or roll back immediately to restore service.

You choose to roll back. Using kubectl and the Kubernetes Dashboard, you manually trigger the rollback while watching pod states transition in real time. After what feels like an eternity, the service stabilizes. You check your stopwatch: the entire recovery took 68 seconds. Your SLA allows for 120 seconds of downtime, so you're technically within bounds—but barely.

Later that evening, you reflect on the incident. What if the rollback had taken longer? What if multiple failures had occurred simultaneously? How can you be confident that your recovery procedures will work under even more stressful conditions? This is where the shift from reactive incident response to proactive resilience testing becomes critical.

---

## Why This Matters for SRE

In traditional software development, teams test that systems work under ideal conditions. In Site Reliability Engineering, the real challenge is ensuring systems recover gracefully when conditions are far from ideal. This lab teaches you the fundamental progression that defines mature SRE practices: moving from manual troubleshooting during live incidents to automated, hypothesis-driven resilience testing before incidents occur in production.

**Manual incident response** teaches you how Kubernetes self-healing works, how to measure Mean Time to Recovery (MTTR), and how to use observability tools under pressure. These are essential foundational skills. However, manual response is reactive—you only discover weaknesses when real failures happen, often at the worst possible times.

**Automated chaos engineering** shifts this paradigm. Instead of waiting for production failures, you proactively inject controlled faults into your systems on a regular schedule. You define success criteria in advance using YAML-based ChaosEngine definitions, measure resilience scores automatically through structured ChaosResult resources, and build confidence that your recovery procedures work long before customers are affected. This is the difference between junior SREs who respond to incidents and senior SREs who prevent incidents through systematic testing.

This lab demonstrates both approaches using the same target application and the same Kubernetes cluster. You'll experience firsthand why industry-leading SRE teams invest in chaos engineering practices, and you'll gain practical skills with both native Kubernetes tools and production-grade chaos frameworks using Infrastructure as Code principles.

---

## Learning Objectives

By completing this lab, you will be able to:

1. Execute emergency rollback procedures under simulated production stress using kubectl and the Kubernetes Dashboard, observing pod lifecycle transitions and manually measuring MTTR.

2. Design and execute automated chaos experiments using LitmusChaos ChaosEngine YAML definitions, implementing hypothesis-driven success criteria through declarative Infrastructure as Code.

3. Compare manual versus automated chaos approaches by generating a comparative analysis that quantifies differences in measurement accuracy, operational overhead, reproducibility, and version control benefits.

4. Apply production-ready chaos engineering practices by understanding how senior SRE teams build confidence through continuous resilience testing using GitOps workflows rather than reactive firefighting.

---

## Prerequisites

Before starting this lab, you should have:

**Required Knowledge:**
- Basic Kubernetes concepts (pods, deployments, services)
- Familiarity with kubectl commands
- Understanding of container orchestration fundamentals
- Basic YAML syntax and structure

**Required Tools:**
- **Minikube** or similar local Kubernetes cluster
- **kubectl** CLI tool configured
- **Helm** v3+ (for installing LitmusChaos operator)
- **Git** for version control
- Terminal with bash or zsh
- Text editor (vim, nano, VS Code, etc.)

**Recommended But Optional:**
- Docker Desktop or similar container runtime
- Basic understanding of Kubernetes operators
- Familiarity with Custom Resource Definitions (CRDs)

**System Requirements:**
- 4 CPU cores minimum (8 recommended)
- 8 GB RAM minimum (16 GB recommended)
- 20 GB free disk space
- Stable internet connection for pulling images

---

## Theoretical Foundation

### Mean Time to Recovery (MTTR)

Mean Time to Recovery measures how long it takes to restore service after a failure occurs. MTTR is one of the four golden signals of SRE reliability metrics, alongside Mean Time Between Failures (MTBF), Mean Time to Detect (MTTD), and Mean Time to Acknowledge (MTTA). Together, these metrics quantify system resilience and inform SLA targets.

MTTR begins when a failure is detected and ends when normal service is fully restored. For a Kubernetes deployment rollback, this spans from recognizing that pods are failing to confirming that all replacement pods are running and healthy. MTTR includes not just the technical recovery time but also human response time—how long it takes to identify the problem, decide on rollback, and execute the procedure.

In production environments, MTTR directly impacts customer experience and business metrics. If your service promises 99.9% uptime, you have approximately 43 minutes of acceptable downtime per month. A single incident with a 60-second MTTR is manageable, but repeated incidents or a single incident with 30-minute MTTR can violate your SLA and damage customer trust.

SRE teams use MTTR data to drive continuous improvement. By measuring MTTR across multiple incidents, you identify patterns—perhaps rollbacks during peak traffic take longer due to resource contention, or certain types of failures have unpredictable recovery times. This data informs infrastructure improvements, automation investments, and runbook refinements.

### Manual Incident Response vs Automated Chaos

Manual incident response is the foundational skill every SRE develops early in their career. When production fails, you open your observability dashboards, examine logs and metrics, hypothesize about the cause, and take corrective action. You measure MTTR by noting timestamps or using a stopwatch. You document the incident afterward in a postmortem. This reactive approach is necessary and valuable—incidents will always require human judgment and intervention.

However, manual response has inherent limitations. You only test recovery procedures when real failures occur, discovering weaknesses at the worst possible moment when customers are impacted. Manual MTTR measurement is imprecise due to human reaction time and distractions during high-stress incidents. Reproducing the exact conditions of a past incident is difficult, making it hard to verify that improvements actually reduced MTTR. Most critically, manual testing doesn't scale—as infrastructure complexity grows, you cannot feasibly test every failure mode through ad-hoc experimentation.

Automated chaos engineering using YAML-based definitions flips this model. Instead of waiting for failures, you intentionally inject faults on a schedule by applying ChaosEngine custom resources—perhaps via CronJob, or after every deployment through CI/CD pipelines. You define success criteria before the experiment runs using declarative probes: "the system will maintain 95% availability with sub-2-second response times." The LitmusChaos operator executes the experiment, measures outcomes automatically through continuous probes, and generates structured ChaosResult resources with pass/fail verdicts. You build a historical database of resilience metrics stored as version-controlled YAML that shows whether changes improved or degraded system behavior.

The transition from manual to automated chaos represents operational maturity. Junior SREs respond to incidents reactively. Senior SREs design systems that are tested proactively using Infrastructure as Code principles. The automation doesn't replace human expertise—it amplifies it by providing consistent, reproducible data that informs better architectural decisions and reveals weaknesses before they cause customer impact.

### Chaos Engineering Principles

Chaos engineering emerged from Netflix's experience operating large-scale distributed systems. The core insight is that complex systems fail in unexpected ways, and the only way to build confidence in resilience is to deliberately inject failures and observe behavior. Chaos Monkey, Netflix's original chaos tool, randomly terminated production instances to ensure systems could handle failures gracefully.

Modern chaos engineering follows four key principles. First, define steady state—establish measurable indicators of normal system behavior like request latency, error rates, and throughput. Second, hypothesize that steady state will continue in both control and experimental groups. Third, introduce variables that reflect real-world events like server crashes, network latency, or resource exhaustion. Fourth, try to disprove the hypothesis by looking for differences in steady state between control and experimental groups.

The scientific method underlies chaos engineering. You form a hypothesis about system behavior under specific failure conditions. You design an experiment with measurable outcomes using ChaosEngine YAML. You execute the experiment in a controlled manner through the LitmusChaos operator. You analyze results objectively from ChaosResult resources to determine whether your hypothesis was correct. If the system behaves as expected, you gain confidence. If it doesn't, you've discovered a weakness before customers experienced it.

Blast radius control is essential. Start with the smallest possible scope—a single pod in a development environment using `PODS_AFFECTED_PERC: '33'`. Gradually expand to larger scopes as confidence grows—multiple pods, entire services, production environments. Always have abort mechanisms ready. Define maximum acceptable impact in your probe success criteria and halt experiments if that threshold is exceeded. The goal is learning, not causing actual outages.

### LitmusChaos Architecture

LitmusChaos is an open-source chaos engineering platform designed specifically for Kubernetes environments. It uses Kubernetes-native patterns including Custom Resource Definitions (CRDs) and the operator pattern to execute chaos experiments declaratively. This lab uses the core LitmusChaos operator with YAML-based experiment definitions, following Infrastructure as Code principles.

The Chaos Operator runs as a set of controllers watching for ChaosEngine custom resources. When you create a ChaosEngine resource using `kubectl apply -f`, the operator reads its specification, identifies target pods using label selectors, and applies the specified chaos fault. Faults are implemented as Kubernetes Jobs that run chaos experiment containers. These containers use techniques like deleting pods, injecting CPU/memory stress, or manipulating network packets to simulate failures.

ChaosEngine resources reference ChaosExperiment templates that define specific fault types. LitmusChaos includes a library of pre-built experiments covering common failure scenarios—pod deletion, resource exhaustion, network latency, disk fill, and many others. Each experiment has configurable parameters controlling intensity, duration, and target selection using environment variables in the YAML specification. The operator monitors experiment execution and records results in ChaosResult custom resources.

---

**Key Resources:**
- [What is chaos engineering?](https://www.ibm.com/think/topics/chaos-engineering)
- [Google SRE Book - Testing for Reliability](https://sre.google/sre-book/testing-reliability/)
- [LitmusChaos Documentation](https://docs.litmuschaos.io/)

**Video Tutorials:**
- [What is Chaos Engineering? (10 min)](https://www.youtube.com/watch?v=NxQrTGGO-Tc) - Harness
- [Engineering for Chaos: Preparing for Disaster (10 min)](https://www.youtube.com/watch?v=BasOy54QGKo) - TEDx Talks

---

## Lab Structure

### Phase 1: Environment Setup

**Objective:** Deploy the chaos target application and install the LitmusChaos operator to establish infrastructure for manual and automated resilience testing using YAML-based experiments.

See [phase-1-environment-setup.md](phase-1-environment-setup.md) for complete instructions.

### Track 1: Emergency Rollback Drill (Manual Response)

**Objective:** Simulate production incident response by manually injecting pod deletion chaos, executing emergency rollback procedures, and measuring MTTR using kubectl and Kubernetes Dashboard.

See [track-1-manual-response.md](track-1-manual-response.md) for complete instructions.

### Track 2: Scheduled Resilience Testing (Automated Chaos)

**Objective:** Design and execute automated chaos experiments using ChaosEngine YAML definitions, implementing hypothesis-driven success criteria through Infrastructure as Code and measuring resilience through continuous probes.

See [track-2-automated-chaos.md](track-2-automated-chaos.md) for complete instructions.

### Final Phase: Comparative Analysis & Cleanup

**Objective:** Compare manual versus automated approaches by analyzing MTTR measurements, operational overhead, version control benefits, and reproducibility, then generate a comprehensive comparison report and clean up all infrastructure.

See [final-phase-analysis.md](final-phase-analysis.md) for complete instructions.

---
