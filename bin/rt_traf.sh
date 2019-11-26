#!/bin/bash

cat /proc/$1/net/netstat | grep 'IpExt: ' | tail -n 1 | awk '{ print $8 "\t" $9 }'
