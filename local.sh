#!/bin/bash

# Nodes list
NODES=("worker-0" "worker-1" "worker-2")

# Array to store device paths
DEVICE_PATHS=()

# Fetch disk IDs for each node
for node in "${NODES[@]}"; do
    echo "Fetching disk ID from $node..."
    ssh core@$node sudo scsi-rescan -a
    # Fetch up to two disk names from lsblk
    DISK_NAMES=$(ssh core@$node "lsblk | grep 500 | awk '{print \$1}'")

    FOUND_DISK_ID=""

    for DISK_NAME in $DISK_NAMES; do
        echo "Checking disk: $DISK_NAME on $node"

        # Fetch the disk ID based on the disk name
        DISK_ID=$(ssh core@$node "ls -l /dev/disk/by-id/ | grep \"$DISK_NAME\" | head -n 1 | awk '{print \"/dev/disk/by-id/\" \$9}'")

        if [[ -n "$DISK_ID" ]]; then
            FOUND_DISK_ID="$DISK_ID"
            echo "Disk ID found for $DISK_NAME on $node: $DISK_ID"
            DEVICE_PATHS+=("- $DISK_ID")  # Add to DEVICE_PATHS array
            break  # Stop checking if we find a valid disk ID
        fi
    done

    if [[ -z "$FOUND_DISK_ID" ]]; then
        echo " No disk ID found for any disk on $node."
    fi
done

# Create the LocalVolume YAML dynamically and apply it using oc
cat <<EOF | oc apply -f -
apiVersion: local.storage.openshift.io/v1
kind: LocalVolume
metadata:
  name: localblock
  namespace: openshift-local-storage
spec:
  logLevel: Normal
  managementState: Managed
  nodeSelector:
    nodeSelectorTerms:
      - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
              - worker-0
              - worker-1
              - worker-2
  storageClassDevices:
    - devicePaths:
$(printf "        %s\n" "${DEVICE_PATHS[@]}")
      storageClassName: localblock
      volumeMode: Block
EOF
