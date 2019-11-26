#! /bin/bash

# for i in `cat liste2.txt`; do ./chassis_status.sh $i; done

SC=$1
P1=`echo $SC | cut -c1 | awk '{print toupper($0)}'`
P2=`echo $SC | cut -c2 | awk '{print toupper($0)}'`
P3=`echo $SC | cut -c3`
PASSWORD=$P1$P2$P3"4ILOM"
ipmitool -I lanplus -H ${SC}-sc -U root -P $PASSWORD chassis power status || echo "**** ipmitool $SC KO *****"
