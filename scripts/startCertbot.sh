#!/bin/sh

while :; do
  sleep 1d
  date
  certbot renew
done
