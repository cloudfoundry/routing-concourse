# Stemcell Debugging Guide

How to build, inspect and debug stemcells used in HAProxy acceptance tests.

## Development Version of Stemcell

After making changes in the repository, build a local stemcell, upload it to your BOSH environment, and reference it in your manifest. Follow the [Quick Start guide](https://github.com/cloudfoundry/bosh-linux-stemcell-builder/blob/ubuntu-jammy/README.md#quick-start-building-a-stemcell-locally).

The sections below explain what to look for inside the stemcell repository when a stemcell doesn't behave as expected.

### Build Stages

Stemcell creation has two phases:

1. **General stages** — applied to any OS image for the chosen OS type:
   ```bash
   bundle exec rake stemcell:build_os_image[ubuntu,noble,${PWD}/tmp/ubuntu_base_image.tgz]
   ```

2. **Infrastructure-specific stages** — applied only for the target infrastructure (AWS, Google, Warden, etc.), defined in the [stage collection](https://github.com/cloudfoundry/bosh-linux-stemcell-builder/blob/ubuntu-jammy/bosh-stemcell/lib/bosh/stemcell/stage_collection.rb#L49):
   ```bash
   bundle exec rake stemcell:build_with_local_os_image[warden,boshlite,ubuntu,noble,${PWD}/tmp/ubuntu_base_image.tgz]
   ```

> **Note**: For HAProxy acceptance tests the infrastructure is Warden/BOSHlite.

## VM Creation Flow

```
OS Image → Stemcell → BOSH Environment → Deployed VM
```

| Step | What happens |
|------|--------------|
| OS Image | Base operating system |
| Stemcell | OS image packaged with infrastructure metadata |
| Upload to BOSH | Stemcell made available in the cloud BOSH environment |
| VM Creation | Docker CPI applies additional OS tuning via the VM factory service |

> ⚠️ **Important**: The Docker CPI VM factory service may modify or remove stemcell configurations at VM creation time. If the deployed VM state doesn't match the stemcell, this is the likely cause.
