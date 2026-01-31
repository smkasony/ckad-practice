#!/bin/bash
set -euo pipefail

ns=default
name=backup-job

kubectl get cronjob "$name" -n "$ns" >/dev/null

schedule=$(kubectl get cronjob "$name" -n "$ns" -o jsonpath='{.spec.schedule}')
if [[ "$schedule" != "*/30 * * * *" ]]; then
  echo "CronJob $name schedule must be '*/30 * * * *' (got '$schedule')" >&2
  exit 1
fi

succ=$(kubectl get cronjob "$name" -n "$ns" -o jsonpath='{.spec.successfulJobsHistoryLimit}')
fail=$(kubectl get cronjob "$name" -n "$ns" -o jsonpath='{.spec.failedJobsHistoryLimit}')

if [[ "$succ" != "3" ]]; then
  echo "CronJob $name successfulJobsHistoryLimit must be 3 (got '$succ')" >&2
  exit 1
fi

if [[ "$fail" != "2" ]]; then
  echo "CronJob $name failedJobsHistoryLimit must be 2 (got '$fail')" >&2
  exit 1
fi

ads=$(kubectl get cronjob "$name" -n "$ns" -o jsonpath='{.spec.jobTemplate.spec.activeDeadlineSeconds}')
if [[ "$ads" != "300" ]]; then
  echo "CronJob $name jobTemplate.spec.activeDeadlineSeconds must be 300 (got '$ads')" >&2
  exit 1
fi

rp=$(kubectl get cronjob "$name" -n "$ns" -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}')
if [[ "$rp" != "Never" ]]; then
  echo "CronJob $name restartPolicy must be Never (got '$rp')" >&2
  exit 1
fi

image=$(kubectl get cronjob "$name" -n "$ns" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')
if [[ "$image" != "busybox:latest" ]]; then
  echo "CronJob $name container image must be busybox:latest (got '$image')" >&2
  exit 1
fi

cmd=$(kubectl get cronjob "$name" -n "$ns" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].command[*]}')
args=$(kubectl get cronjob "$name" -n "$ns" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].args[*]}')

combined="$cmd $args"
# Accept a few common implementations, but require the intent: echo + Backup completed
if ! echo "$combined" | grep -q "echo"; then
  echo "CronJob $name container must run an echo command (got: $combined)" >&2
  exit 1
fi
if ! echo "$combined" | grep -q "Backup" || ! echo "$combined" | grep -q "completed"; then
  echo "CronJob $name container must echo 'Backup completed' (got: $combined)" >&2
  exit 1
fi
