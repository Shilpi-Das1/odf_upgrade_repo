#!/bin/bash

set -euo pipefail

TOOLS_POD=$(oc get pods -n openshift-storage | grep rook-ceph-tools | awk '{print $1}')
NAMESPACE="openshift-storage"

echo "osd.0"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config get osd.0  bluefs_buffered_io"
echo "osd.1"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config get osd.1  bluefs_buffered_io"
echo "osd.2"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config get osd.2  bluefs_buffered_io"

echo "===== Disabling bluefs_buffered_io ====="
echo "osd.0"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config set osd.0  bluefs_buffered_io false"
echo "osd.1"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config set osd.1  bluefs_buffered_io false"
echo "osd.2"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config set osd.2  bluefs_buffered_io false"

echo "===== Restarting OSD Pods One-by-One ====="
OSD_PODS=$(oc get pods -n $NAMESPACE -o name | grep rook-ceph-osd)


echo "===== Restarting OSD Deployments One-by-One ====="

DEPLOYMENTS=$(oc get deploy -n "$NAMESPACE" -o name | grep rook-ceph-osd)

for deploy in $DEPLOYMENTS; do
  deploy_name=$(basename "$deploy")
  echo "🔄 Restarting Deployment: $deploy_name"
  
  # Trigger rollout restart
  oc rollout restart -n "$NAMESPACE" deployment "$deploy_name"

  echo "⏳ Waiting for $deploy_name to complete rollout..."
  oc rollout status -n "$NAMESPACE" deployment "$deploy_name" --timeout=300s
done

echo "===== Verifying bluefs_buffered_io Settings After Restart ====="
echo "osd.0"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config get osd.0  bluefs_buffered_io"
echo "osd.1"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config get osd.1  bluefs_buffered_io"
echo "osd.2"
oc -n $NAMESPACE rsh $TOOLS_POD sh -c "ceph config get osd.2  bluefs_buffered_io"

