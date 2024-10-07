#!/bin/bash -e
# Run with sudo.

DEV=/dev/"$1"
TARGET="$2"
FSTYPE=ext4

if mount | grep "$TARGET" >/dev/null; then
  echo "Found mounted workspace filesystem $TARGET"
else
  echo "workspace mount not found"

  if [ -d "$TARGET" ]; then
    echo "Found workspace folder"
  else
    mkdir -p "$TARGET"
    echo "Created workspace folder"
  fi
  chown "$3":"$3" "$TARGET" || true
  if [ "$3" == concourse ]; then
    chmod g+sw "$TARGET" || true
  fi

  if [ ! -b "${DEV}1" ]; then
    echo "file system device not found"
    if [ ! -b "$DEV" ]; then
      echo "volume device $DEV not found or no block device"
      exit 1
    fi

    if ! fdisk -l "$DEV" 2>&1 | grep "${DEV}1" >/dev/null; then
      echo "volume not prepared"
      echo -e "n\\np\\n\\n\\n\\nw\\nw\\n" | fdisk "$DEV"
      mkfs -t "$FSTYPE" "${DEV}1" || { echo "cannot create filesystem">&2; exit 1; }
      echo "Created volume filesystem"
    else
      echo "Found partition table"
      echo -e "p\\nw\\n" | fdisk "$DEV" # (re)create device file
    fi
  else
    echo "Found file system device"
  fi

  if grep "${DEV}1" </etc/fstab >/dev/null; then
    echo "Found workspace fstab entry"
  else
    echo "${DEV}1         $TARGET   $FSTYPE   defaults  0 0" >> /etc/fstab
    echo "Created workspace fstab entry"
  fi
  mount "$TARGET" || { echo "cannot mount filesystem">&2; exit 1; }
  chown "$3":"$3" "$TARGET" || true
  echo "Mounted workspace"
fi
