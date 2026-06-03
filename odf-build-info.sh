#!/bin/bash
echo "--------------------START-------------------";echo
echo "#######  oc get clusterversion  #######";echo; oc get clusterversion; echo
echo "#######  oc get nodes  #######";echo; oc get nodes; echo
echo "#######  oc get csv -A  #######";echo; oc get csv -A; echo
echo "#######  oc get pods -n openshift-local-storage  #######";echo; oc get pods -n openshift-local-storage; echo
echo "#######  oc get localvolume -n openshift-local-storage  #######";echo; oc get localvolume -n openshift-local-storage; echo
echo "#######  oc get pods -n openshift-storage  #######";echo; oc get pods -n openshift-storage; echo
echo "#######  oc get pv  #######";echo; oc get pv; echo
echo "#######  oc get pvc -n openshift-storage  #######";echo; oc get pvc -n openshift-storage; echo
echo "#######  oc get sc -n openshift-storage  #######";echo; oc get sc -n openshift-storage; echo
echo "#######  oc get storagecluster -n openshift-storage  #######";echo; oc get storagecluster -n openshift-storage; echo
echo "#######  ceph -s  #######";echo; oc -n openshift-storage rsh `oc get pods -n openshift-storage | grep rook-ceph-tools |  awk '{print $1}'` ceph -s; echo
echo "#######  ceph version  #######";echo; oc -n openshift-storage rsh `oc get pods -n openshift-storage | grep rook-ceph-tools |  awk '{print $1}'` ceph version; echo
echo "#######  oc get cephcluster -n openshift-storage  #######";echo; oc get cephcluster -n openshift-storage; echo
echo "#######  oc get storagesystem -n openshift-storage  #######"; echo;oc get storagesystem -n openshift-storage; echo
echo "#######  oc get backingstore -n openshift-storage  #######";echo; oc get backingstore -n openshift-storage; echo
echo "#######  oc get bucketclass -n openshift-storage  #######";echo; oc get bucketclass -n openshift-storage; echo
echo "#######  oc get noobaa -n openshift-storage  #######";echo; oc get noobaa -n openshift-storage; echo
echo "#######  ODF build  #######"; 
odf_csv=$(oc get csv -n openshift-storage -o name | grep odf-operator)
oc get "$odf_csv" -n openshift-storage -o jsonpath='{.metadata.labels.full_version}'
echo
echo "--------------------END-------------------"; echo
