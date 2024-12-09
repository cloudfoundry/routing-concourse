#!/bin/bash -e

CONCOURSE_PASSWORD=$(grep CONCOURSE_ADMIN_PWD /concourse/.concourse.env | cut -d = -f 2)
# Log in to Concourse
fly -t networking-extensions login -c https://concourse.arp.cloudfoundry.org/ -u admin_concourse -p "$CONCOURSE_PASSWORD"

# Prune workers
fly -t networking-extensions prune-worker --all-stalled
