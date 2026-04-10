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

> **Note**: Use `sudo -Es` on the VM to run Docker commands.

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

---

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

---

## Process Monitoring

### Check a Process with Monit

```bash
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
