#!/bin/bash

IF=${1:-"eth0"}
INTERVAL=${2:-1}  # update interval in seconds

while true
do
        R1=`cat /sys/class/net/$IF/statistics/rx_bytes`
        T1=`cat /sys/class/net/$IF/statistics/tx_bytes`
        sleep $INTERVAL
        R2=`cat /sys/class/net/$IF/statistics/rx_bytes`
        T2=`cat /sys/class/net/$IF/statistics/tx_bytes`
        TBPS=`expr $T2 - $T1`
        RBPS=`expr $R2 - $R1`
        # TKBPS=`expr $TBPS / 1024 / 1024`
        # RKBPS=`expr $RBPS / 1024 / 1024`
        #echo "TX $1: $TKBPS mB/s RX $1: $RKBPS mB/s"
        MB=`expr 1024 \* 1024`
        KB=1024  
        SCALE=0
        TKBPS=`echo "scale=$SCALE;$TBPS/$KB/$INTERVAL"| bc` # && echo $TKBPS
        RKBPS=`echo "scale=$SCALE;$RBPS/$KB/$INTERVAL"| bc` # && echo $RKBPS
        TOTAL=`echo "scale=$SCALE;$RKBPS+$TKBPS"|bc`
        TIMESTAMP=`date "+%d-%m-%Y %H:%M:%S"`
        # echo "$TIMESTAMP RX $IF: $RKBPS kB/s TX $IF: $TKBPS kB/s | Total : $TOTAL kB/s"
        printf "$TIMESTAMP | $IF | RX: %6d kB/s | TX: %6d kB/s | Total: %6d kB/s\n" $RKBPS $TKBPS $TOTAL
done
