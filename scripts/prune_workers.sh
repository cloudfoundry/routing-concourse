#!/bin/bash -e

# Log in to Concourse
fly -t networking-extensions login -c https://concourse.arp.cloudfoundry.org/ -u admin_concourse -p `grep CONCOURSE_ADMIN_PWD /concourse/.concourse.env | cut -d = -f 2`

# Prune workers
fly -t networking-extensions prune-worker --all-stalled
