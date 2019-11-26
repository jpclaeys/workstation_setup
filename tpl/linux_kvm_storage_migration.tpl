In each node of the cluster:
VM_NAME=<vmname>

for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done

/opt/emc/SYMCLI/bin/symrdf -g $VM_NAME-1 query
for i in `/opt/emc/SYMCLI/bin/symrdf -g $VM_NAME-1 query | grep ^DEV | awk '{print $1}'`; do echo $i && symdg -g $VM_NAME-1 show ld $i | grep 'Device WWN';done

symdg -g $VM_NAME-1 show ld DEV002 | grep 'Device WWN'

multipath -ll |grep -A6 mpath

    multipath {
       wwid 360000970000296700060533030374242
       alias qccoord-tk_vmax3_t1_system1
    }

    multipath {
       wwid 360000970000296700060533030374243
       alias qccoord-tk_vmax3_t1_data1
    }

vim /etc/multipath.conf
multipath -d -v 2
service multipathd reload

ls -lh /dev/mapper/$VM_NAME*

pcs status |grep $VM_NAME

pcs resource disable $VM_NAME

sync
echo 3 > /proc/sys/vm/drop_caches

echo "time dd if=/dev/mapper/${VM_NAME}_t1_system1 of=/dev/mapper/${VM_NAME}_vmax3_t1_system1 bs=64K conv=noerror,sync status=progress"
echo "time dd if=/dev/mapper/${VM_NAME}_t1_data1   of=/dev/mapper/${VM_NAME}_vmax3_t1_data1   bs=64K conv=noerror,sync status=progress"

time dd if=/dev/mapper/${VM_NAME}_t1_system1 of=/dev/mapper/${VM_NAME}-2_t1_system1 bs=64K conv=noerror,sync status=progress
time dd if=/dev/mapper/${VM_NAME}_t1_data1   of=/dev/mapper/${VM_NAME}-2_t1_data1 bs=64K   conv=noerror,sync status=progress

ddrescue -v -f -n -b 65536 /dev/mapper/${VM_NAME}_t1_system1 /dev/mapper/${VM_NAME}_vmax3_t1_system1
ddrescue -v -f -n -b 65536 /dev/mapper/${VM_NAME}_t1_data1   /dev/mapper/${VM_NAME}_vmax3_t1_data1
ddrescue -v -f -n -b 65536 /dev/mapper/${VM_NAME}_t1_data2   /dev/mapper/${VM_NAME}_vmax3_t1_data2

partprobe /dev/mapper/${VM_NAME}_vmax3_t1_system1
partprobe /dev/mapper/${VM_NAME}_vmax3_t1_data1

ls -lh /dev/mapper/*$VM_NAME*

virsh edit $VM_NAME

for node in `crm_node -p | sed "s/$(hostname -s)-cl//g"`; do echo -n "$node: " && virsh -c qemu+ssh://$node/system define /etc/libvirt/qemu/$VM_NAME.xml; done

pcs resource enable $VM_NAME
pcs status |grep $VM_NAME

check boot progress:
virt-viewer --connect qemu+ssh:://iodine/system


Post-check on the VM:
---------------------

ssh $VM_NAME
df -hlT
lsblk
dmesg
cat /etc/fstab : check if the fsck flag is set; set 0 0 to skip the fsck



Centreon comment:
lopmarc: Storage migration

Retirer les disques


# Remove luns
--------------
4.2 on the 4 nodes delete old entries in multipath.conf.
---------------------------------------------------------
# Comment out or delete the multipath lines of the previous LUNs and do a service reload again :
# remove old devices
vi /etc/multipath.conf 
# validate config file
multipath -d -v 2  
# restart the service
service multipathd reload

# Verify the old entries have been removed :

ls -lh /dev/mapper/${VM_NAME}*
if they still exist,  run the "removelun_rhel" script to delete the luns :

removeluns=/home/admin/bin/removelun_rhel
$removeluns ${VM_NAME}_t1_system1
# if ok, then execute the cmds
$removeluns ${VM_NAME}_t1_system1 | bash

$removeluns ${VM_NAME}_t1_data1
# if ok, then execute the cmds
$removeluns ${VM_NAME}_t1_data1 | bash

# Check tha the disks have been removed
ls -lh /dev/mapper/${VM_NAME}*
