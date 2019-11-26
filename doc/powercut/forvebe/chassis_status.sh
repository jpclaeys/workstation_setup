#! /bin/bash

SC=$1
P1=`echo $SC | cut -c1 | awk '{print toupper($0)}'`
P2=`echo $SC | cut -c2 | awk '{print toupper($0)}'`
P3=`echo $SC | cut -c3`
PASSWORD=$P1$P2$P3"4ILOM"

ping -c1 -W1 $SC 1>/dev/null 2>/dev/null 
if [ $? -eq 0 ]
then
  echo -n "## $SC - "
  ipmitool -I lanplus -H $SC -U root -P $PASSWORD chassis power status || echo "**** ipmitool $SC KO *****"
  exit 0
else
  echo "**** $SC - NO PING ****"
  exit 1
fi
#ipmitool -I lanplus -H $SC -U root -P $PASSWORD chassis power status
