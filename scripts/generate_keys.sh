#!/bin/bash -e

VERSION="$concourse_version"

cd "$(dirname "$0")"
WORK_DIR="$PWD"

mkdir -p "$WORK_DIR/web"
mkdir -p "$WORK_DIR/worker"

docker run --rm -v "$WORK_DIR/web":/keys concourse/concourse:"$VERSION" \
  generate-key -t rsa -f /keys/session_signing_key

docker run --rm -v "$WORK_DIR/web":/keys concourse/concourse:"$VERSION" \
  generate-key -t ssh -f /keys/tsa_host_key

docker run --rm -v "$WORK_DIR/worker":/keys concourse/concourse:"$VERSION" \
  generate-key -t ssh -f /keys/worker_key

cp "$WORK_DIR/worker/worker_key.pub" "$WORK_DIR/web/authorized_worker_keys"
cp "$WORK_DIR/web/tsa_host_key.pub" "$WORK_DIR/worker"
