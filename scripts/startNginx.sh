#!/bin/sh

apt-get -qq update && apt-get -qq install inotify-tools

while :; do
  inotifywait /etc/letsencrypt/live/"$CONCOURSE_EXTERNAL_DOMAIN"
  echo "### Cert changes detected, reloading nginx in 10s ..."
  sleep 10      # Wait for all the changes to propagate or for nginx to start 1st time
  nginx -s reload
done &

echo "### Starting nginx ..."
/docker-entrypoint.sh nginx -g 'daemon off;'
