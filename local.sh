#!/bin/bash

# Nodes list
NODES=($(oc get nodes | grep worker | awk '{print $1}'))

# Array to store device paths
DEVICE_PATHS=()

# Fetch disk IDs for each node
for node in "${NODES[@]}"; do
    echo "Fetching disk ID from $node..."

    echo "--------------------lsblock before -------------------"
    echo
    oc debug node/"$node" -- chroot /host lsblk
    oc debug node/"$node" -- chroot /host scsi-rescan -a
    echo "--------------------lsblock after -------------------"
    echo
    oc debug node/"$node" -- chroot /host lsblk

    DISK_NAMES=$(oc debug node/"$node" -- chroot /host bash -c "lsblk | grep 500 | awk '{print \$1}'" 2>/dev/null)

    FOUND_DISK_ID=""

    for DISK_NAME in $DISK_NAMES; do
        echo "Checking disk: $DISK_NAME on $node"

        DISK_ID=$(oc debug node/"$node" -- chroot /host bash -c "ls -l /dev/disk/by-id/ | grep \"$DISK_NAME\" | head -n 1 | awk '{print \"/dev/disk/by-id/\" \$9}'" 2>/dev/null)

        if [[ -n "$DISK_ID" ]]; then
            FOUND_DISK_ID="$DISK_ID"
            echo "Disk ID found for $DISK_NAME on $node: $DISK_ID"
            DEVICE_PATHS+=("- $DISK_ID")  # Add to DEVICE_PATHS array
            break  # Stop checking if we find a valid disk ID
        fi
    done

    if [[ -z "$FOUND_DISK_ID" ]]; then
        echo "No disk ID found for any disk on $node."
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
$(printf "              - %s\n" "${NODES[@]}")
  storageClassDevices:
    - devicePaths:
$(printf "        %s\n" "${DEVICE_PATHS[@]}")
      storageClassName: localblock
      volumeMode: Block
EOF
