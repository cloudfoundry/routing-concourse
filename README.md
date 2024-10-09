# App Runtime Platform Concourse

[concourse.arp.cloudfoundry.org](https://concourse.arp.cloudfoundry.org)

This is the concourse server for App Runtime Platform workgroup. It hosts CI pipelines for git automation, PR and release builds.

Over time there will also be any other useful (maintenance) pipelines, albeit not publicly viewable.

## Architecture

Concourse server is deployed on a single VM in Google Cloud Platform, using terraform to [organise cloud resources](terraform/concourse/) (DNS, VPC, FW access) and bootstrap the server. Terraform state is persisted in [GCS bucket](https://storage.cloud.google.com/arp-concourse-state/terraform/state/default.tfstate?authuser=0), see [TF definition](terraform/state/bucket.tf).

Concourse itself and other services (worker, postgres, nginx, certbot) are deployed with [docker compose](docker-compose.yml) from official containers. Certificates are automatically renewed via [certbot](scripts/startCertbot.sh) and [nginx](scripts/startNginx.sh) automation. SSH access uses google [Identity Aware Proxy](https://cloud.google.com/iap/docs/concepts-overview).

## Authentication to concourse

There are multiple ways to log in to Concourse:

- 'main' team membership: Members of `wg-app-runtime-platform-networking-extensions-approvers` team in [cloudfoundry org](https://github.com/orgs/cloudfoundry/people) can log in and do all team operations (build comments, triggering new builds, editing, creating or deleting pipelines, making pipelines publicly viewable)
- Anonymous access is allowed. Pipelines that are publicly exposed will be viewable, but it is not possible to do any operations.
- Admin access is possible via technical `admin_concourse` user, how to obtain the password from `.concourse.env` is described in [the Deployment section](#deployment) below

## Accessing server via SSH

In order to be able to ssh into concourse server, you need to have user account in `app-runtime-platform-wg` GCP project. On top of that, access goes via [Identity Aware Proxy](https://cloud.google.com/iap/docs/concepts-overview), for which you need extra privileges: `IAP-secured Tunnel User` and `IAP-secured Web App User`. These are already part of `owner` role, but `editor` needs to have them explicitly added. Purpose of this proxy is that the server does not need to expose ssh on port 22 on the internet. Also, there is no management of user ssh keys.

To get to the server, you need to:

- [install gcloud CLI](https://cloud.google.com/sdk/docs/install)
- then you need to authenticate: `gcloud auth login`
- then it is advised you select your project: `gcloud config set project app-runtime-platform-wg`. In case you don't have access to any other GCP projects, this might not be necessary
- finally, ssh to server: `gcloud compute ssh concourse --zone europe-west3-a --tunnel-through-iap`. It is important that you `--tunnel-through-iap` as otherwise access might not work. Concourse is currently located in europe-west3-a (Frankfurt) zone, that also needs to be specified, as otherwise CLI won't be able to find server by it's `concourse` name. Once you are in, you will be able to sudo. Also, your local username will be used for ssh, which does not need to match your name in gcloud.

## Managing pipelines

There are no default pipelines in this repository. To upload, edit and otherwise manage pipelines you can use `fly` and standard concourse ways of doing things. The `main` team is the main team and any publicly visible pipelines should be added here. The pipelines need to be made publicly viewable explicitly (either with [`fly expose-pipeline`](https://concourse-ci.org/managing-pipelines.html#fly-expose-pipeline)) or having `public: true` on jobs in pipeline definition.

## Deployment

Server is fully deployed with terraform, which creates supporting infrastructure and then runs provisioning scripts. You need to [install terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) of version at least 0.12. You also need to have a role in GCP that allows creating and managing resources created by TF. `editor` is sufficient, `owner` is superset of editor. Because provisioning script uses ssh to access the server, you need to be able to do that - see [Accessing server via SSH](#accessing-server-via-ssh) section above.

Because terraform uses implicit gcloud authentication, you need to log in for application use: `gcloud auth application-default login` in addition to `gcloud auth login` that's required for provisioning which works via ssh.

After installing terraform, `cd terraform/concourse` and do `terraform init`. This will pull in required provisioners at versions stored in `.terraform.lock.hcl`. Then you can do `terraform plan` and other usual TF operations. By default, and while this repository and deployment is in good shape, starting clean and running `terraform apply` should do no changes, but it will generate local `.concourse.env` file with environment vars for docker compose. This environment file contains among other things password for `admin_concourse` user. If you don't have gcloud access, or your `application-default` login has expired, terraform will fail generating this file, as the credentials are stored in the tf statefile in GCS bucket.

Once all cloud resources are created, terraform will run provisioning scripts. These are first copied to concourse server using `gcloud scp` and then run with `gcloud ssh`. These scripts will install all required tools and OS packages, upload docker-compose config and startup scripts, obtain initial certificate, configure cgroups to v1 (required for concourse worker) and start all the components (nginx, concourse, concourse worker, postgres and certbot). There is one system reboot after initial provisioning, in order to apply cGroup changes. The scripts are idempotent and terraform is watching local changes to scripts and config files and will run provision on any changes when you `terraform apply`. If there are any failures, mostly due to various race-conditions (e.g. the VM has not yet booted after 30s and ssh to it failed), please run `terraform apply` again.

Note that gcloud tools will recommend to install NumPy in order to increase network performance. Nevertheless, even after installing this, the recommendations don't stop, hence all gcloud calls have `--verbosity=error` to suppress this log output.

## Persistence

There is a single persistent disk attached to concourse VM (mounted in `/workspace`). This disk hosts all docker data (images), current and previous certificates and postgres database. It is thus fine to re-create concourse VM (`terraform taint google_compute_instance.concourse ; terraform apply`), e.g. for re-sizing the disk.

## Certificate management

Certificates are managed by certbot. When the VM is created for the 1st time, provision scripts will create dummy certs, start nginx and then obtain real certificate from letsencrypt. Nginx is specifically configured to have access to the certs obtained by certbot and to be able to respond to ACME challenges. Afterwards certbot keeps running and will try to obtain new certificate each day. Currently, certs obtained from letsencrypt have 3 month validity and will be considered due for refresh once they have less than 30 days left. Nginx container init script watches for changes in certs and will reload nginx once certs are updated.

There is a special operations parameter - terraform variable `force_new_cert`. Set this to `true` to wipe all existing certs and start from scratch as if the VM was provisioned 1st time. This can be applied by exporting environment variable: `export TF_VAR_force_new_cert=true ; terraform apply ; unset TF_VAR_force_new_cert`.

> [!CAUTION]
>
> If you leave this variable at `true`, new cert will be unnecessarily obtained on each provision scripts run and you will likely hit LetsEncrypt limit of 5 new certs per week. You will only realise this after you have wiped all previous certs and obtaining new cert has failed.

## Credential handling

There are two types of credentials used with this deployment. Concourse admin and postgres passwords are generated with terraform (see below [how to rotate them](#rotating-passwords)). `GITHUB_CLIENT_SECRET` and `GITHUB_CLIENT_ID` are to be provided. In order to improve security and not require user to handle these on every TF run, we have configured terraform to obtain last value from its own state and re-use that. Providing a new value can be done in usual terraform ways - e.g. using environment variables (with TF_VAR_ prefix), using vars file or inputting them with `-var` switch on command line. TF will then subsequently store new values and keep re-using them. This means that you only need to provide these vars when you are changing/rotating the value.

# Operations

Sections below describe most common operations and how to execute them. In general, scripts are idempotent and if there is any failure due to external factors (e.g. race conditions, services not being ready within expected timeouts etc.), you can simply terraform apply again to re-run scripts and re-apply changes.

> [!IMPORTANT]
>
> When making any changes to scripts, configs or terraform files, always commit back to repository. Terraform state gets updated automatically and is stored in GCS bucket and it needs to have matching code.

## Rotating passwords

Both admin_concourse and postgres password are managed by terraform. You can generate new passwords simply by tainting existing resources and then running terraform apply, e.g. `terraform taint random_password.postgres; terraform apply`.

There is a special provisioner for updating postgres password, as that one gets applied from .concourse.env docker-compose environment variables only once when database is created for the 1st time, and requires direct updates with `psql` afterwards.

You can see definitions of credentials in [credentials.tf](terraform/concourse/credentials.tf)

## Change or re-deploy VM

If you want to change any VM parameter, such as disk size or VM type, you can edit VM parameters section of [variables](terraform/concourse/variables.tf) and do `terraform apply`. If you need to do substantial changes, you can edit the terraform definition of [the VM](terraform/concourse/concourse.tf) directly. Don't forget to commit back after you apply.

If you want to re-deploy the VM, you taint it and then apply: `terraform taint google_compute_instance.concourse ; terraform apply`

## Upgrading container versions

All container versions are specified in [docker-versions.sh](docker-versions.sh). You can change them and run `terraform apply`. Don't forget to commit back after you apply.

## Upgrading terraform and providers

If you want to update terraform, please specify required version in [versions.tf](terraform/concourse/versions.tf).

If you need to update any of the provisioners, make sure to commit [.terraform.lock.hcl](terraform/concourse/.terraform.lock.hcl) afterwards.

## Viewing logs

We store 5x 10MB of logs for each container. You can view them by `docker logs <containerID>`. You can use `-f` parameter to follow logs. You can get container IDs by running `docker ps -a`. You need to sudo in order to run docker commands.

> [!WARNING]
>
> As nginx is on the public internet, it gets a lot of spam/attack traffic. Some of that is designed to phish sysadmins viewing logs. Do not follow any links/sites.

## FAQ

This section contains various useful quick tips for server ops and maintenance. Feel free to add your learnings.

- view system logs and logs of individual containers (`docker logs <containerID> -f`)
- restart all the containers with `docker compose --env-file "/concourse/.concourse.env" restart`
- restart individual containers directly with `docker restart <containerID>`

In general, restarts should be harmless, apart from causing downtime during restart (restarting certbot won't cause any downtime, restarting concourse worker might cause just build delays if jobs have retry configured).

If you are doing any changes by hand, don't forget to carry them over back to TF config and scripts, as otherwise next time someone runs TF with provisioning (which happens on any change), the changes will be potentially undone and problems might come back.
