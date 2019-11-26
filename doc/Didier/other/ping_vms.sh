#!/bin/bash
for vm in `cat vmlist.txt | awk -F' ' '{print $1}'`; do
    echo "Pinging $vm..."
    if [[ `ping -c 3 $vm` ]]; then
	echo "UP"
        ssh -o "ConnectTimeout=5" $vm "/bin/uname -a"
    else
	echo "DOWN"
    fi
done
