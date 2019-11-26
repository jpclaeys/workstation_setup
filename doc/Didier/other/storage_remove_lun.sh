#!/bin/bash

mp_info=$(multipath -ll | grep "$1")

if [ ! -z "$mp_info" ]; then
 mp_name=$(echo $mp_info | cut -d ' ' -f 1)
 mp_devices=$(multipath -ll | grep -A 6 "$1" | grep -e "sd.." | cut -d " " -f 5)
 echo  
 echo "LUN : $mp_info"
 echo "SCSI devices for LUN : " $mp_devices
 if [ ! -z "$(grep $1 /etc/multipath/bindings)" ]; then
  echo "LUN found in multipath bindings file"
 else
  echo "LUN not found in multipath bindings file"
 fi
 echo
 read -p "Are you sure to remove this lun from system ? (Y/N): " -n 1 -r
 echo
 if [[ $REPLY =~ ^[Yy]$ ]]
     then
     multipath -f $mp_name
     echo "multipath device flushed"
     for devs in $mp_devices ; do 
      echo 1 > /sys/block/$devs/device/delete
      echo "deleted SCSI device : $devs"
     done
 fi
else
 echo "LUN $1 doesn't exist"
fi
