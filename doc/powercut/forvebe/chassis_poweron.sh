#! /bin/bash

SC=$1
P1=`echo $SC | cut -c1 | awk '{print toupper($0)}'`
P2=`echo $SC | cut -c2 | awk '{print toupper($0)}'`
P3=`echo $SC | cut -c3`
PASSWORD=$P1$P2$P3"4ILOM"

ipmitool -I lanplus -H $SC -U root -P $PASSWORD chassis power on || echo "**** ipmitool $SC KO *****"
