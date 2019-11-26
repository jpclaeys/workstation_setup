#!/bin/bash
# Script to help gather configuration detail
# run on the iSCSI target hosting server
# The output commands can then be run on an iSCSI initiator host
echo ""
/usr/sbin/iscsitadm list target
echo ""
echo "Run these commands on both initiators:"
echo ""
for target in `/usr/sbin/iscsitadm list target | grep "^Target" | awk -
F: '{print $2}'`
do
echo /usr/sbin/iscsiadm add static-config `/usr/sbin/iscsitadm
list target -v $target | grep "iSCSI Name" | awk '{print $NF}'`,$1
done
echo ""
