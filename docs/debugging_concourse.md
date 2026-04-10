# Concourse Debugging Guide

Tips and tricks for the Concourse pipeline and BOSH deployments used in HAProxy acceptance tests.

## Access

### SSH into the Concourse VM

```bash
gcloud auth login
gcloud config set project app-runtime-platform-wg
gcloud compute ssh concourse --zone europe-west3-a --tunnel-through-iap
```

A browser window will open — authenticate with your Google account and grant access to the `gcloud` app.

### Log in with fly

```bash
fly -t networking-extensions login -c https://concourse.arp.cloudfoundry.org/
```

A browser window will open — authenticate with your GitHub account. Your account must be a member of the `wg-app-runtime-platform-networking-extensions-approvers` team.

Alternatively, use the `admin_concourse` credentials stored in `/concourse/.concourse.env` on the Concourse VM.

## Inspecting Running Jobs

1. List all worker containers and find your container: match the Job ID (visible in the web UI) and the task name (e.g. `acceptance-tests`).
2. Use the container handle to get into the container.

```bash
fly -t networking-extensions containers
fly -t networking-extensions intercept --handle <handle UID>
```

**Example**: job `237`, task `acceptance-tests` — the job failed because a BOSH-deployed VM became unhealthy causing one of the acceptance tests fail. To investigate, intercept the task container where the deployment ran.

```
# build # = job ID,  "name" = task name
fly -t networking-extensions containers
handle                                worker        pipeline             job                  build #  build id  type   name
1bb9aeca-f26d-4fe9-7186-05514ad4e861  a6710695276f  haproxy-boshrelease  none                 check    none      check  stemcell
2151af27-bab1-41ca-460b-cb36bb0c9075  a6710695276f  haproxy-boshrelease  acceptance-tests-pr  237      6956168   get    git-pull-requests
5318d0ba-0944-475d-652d-176189c0d37e  a6710695276f  haproxy-boshrelease  acceptance-tests-pr  237      6956168   get    haproxy-boshrelease-testflight
837f5102-46a4-4071-756f-2c5a0d8f58fa  a6710695276f  haproxy-boshrelease  none                 check    none      check  docker-cpi-image
8e7cb3e6-c2e4-41f9-4eee-5f1a2a2ca88c  a6710695276f  haproxy-boshrelease  none                 check    none      check  stemcell-jammy
a93fdd5a-de1c-4141-60a6-627c9754558c  a6710695276f  haproxy-boshrelease  acceptance-tests-pr  237      6956168   put    git-pull-requests
c271db40-83f3-4a10-6e1b-24d2732fd5c6  a6710695276f  haproxy-boshrelease  unit-tests-pr        217      6956167   get    haproxy-boshrelease-testflight
c7756058-6229-422b-5369-9b2434bc183d  a6710695276f  haproxy-boshrelease  acceptance-tests-pr  237      6956168   task   acceptance-tests

# last line is the one we are interested in, so we can run:
fly -t networking-extensions intercept --handle c7756058-6229-422b-5369-9b2434bc183d
```

## System Diagnostics

### Check cgroups Version

```bash
stat -fc %T /sys/fs/cgroup
```

| Output      | cgroups version |
|-------------|-----------------|
| `cgroup2fs` | v2              |
| `tmpfs`     | v1              |

---

## Accessing BOSH-deployed VMs

These commands are for debugging HAProxy VMs created by BOSH.

### BOSH CLI (preferred)

Use when the BOSH environment is up and the director is running and accessible:

```bash
bosh -d haproxy1 ssh haproxy/0
```

### Docker CLI (fallback)

Use when the BOSH deployment has failed or the director is unreachable:

```bash
docker ps                               # the top entry is usually the most recently created VM
docker exec -it <container_id> /bin/bash
```

> **Note**: Run `sudo -Es` on the Concourse VM before running Docker commands.

## Process Monitoring

When an acceptance test fails due to an VM that stuck in an unhealthy state during one of the test deployments, check the process state on that VM for clues.

### Check a Process with Monit

```bash
# Find the deployment with the unhealthy VM by listing all VMs and looking for the "failed" status
bosh vms

# SSH into it
bosh -d haproxy1 ssh haproxy/0

# Summarised status of all processes
monit summary

# Detailed status of a specific processes
monit status | sed -n "/^Process 'postgres'$/,/^$/p"
```

Replace `postgres` with the name of the process you want to inspect.

### List BPM-managed Containers

**Inside a BOSH director VM:**
```bash
/var/vcap/packages/bpm-runc/bin/runc --root /var/vcap/sys/run/bpm-runc list
```

**In other deployments:**
```bash
/var/vcap/packages/bpm/bin/runc --root /var/vcap/sys/run/bpm-runc list
```
