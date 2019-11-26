#!/bin/bash
PATH=$PATH:/bin:/usr/bin:/usr/sbin
INTERFACES=`dladm show-phys| egrep -v 'priv|int'| awk -F"ixgbe" '/ixgbe/ {print $NF}' | xargs` # && echo $INTERFACES
#for i in $INTERFACES ; do kstat -p ixgbe:${i}:statistics | grep fault;done | awk '$NF>0'
for i in $INTERFACES ; do kstat -p ixgbe:${i}:statistics | grep fault;done
