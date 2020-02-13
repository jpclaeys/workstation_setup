------------------------------------------------------------------------------------------------------------------------------------
1 Description
This procedure explains how to migrate storage on a KVM
------------------------------------------------------------------------------------------------------------------------------------

1.1 Send a mail to ask a downtime for the VM (+/- 1 hour)

- Test env: OPDL-INFRA-INT-TEST  cc: OPDL-INFRA-SYSTEMS, JC
- Prod:     OPDL-INFRA-INT-PROD  cc: OPDL-INFRA-SYSTEMS, JC


2 Prerequisites
Check which machines need to be migrated : \\infra1-pk\060_Projet\vmax_to_vmax3

You need to have the new luns from storage team in an excel file.
\\infra1-pk\docs\060_Projet\vmax_to_vmax3


3 Instructions
Consult CMDB to find which clusters are used by the virtual machine.

get the KVM cluster nodes

VM_NAME=<vmname>
cmdb linuxvm | awk -F";" '/'$VM_NAME'/ {print $9}' | xargs

3.1 Setting up variables on the 4 nodes
----------------------------------------

# become root:
sudo -i
# get cluster name (from one of the cluster node)
pcs status | grep "Cluster name"

3.2 Install ddrescue on a node that has RW access on the storage.
------------------------------------------------------------------
yum -y install --enablerepo=DG-OPOCE_EPEL_epel-7 ddrescue

3.3 On each node of the cluster.
--------------------------------
define VM_NAME
ex. 
{
VM_NAME=<vmname>
# Get the symmetrix new diskgroup name
DG_NAME=$VM_NAME && echo "DG_NAME: $DG_NAME"
NEW_DG_NAME=$(symdg list | grep `echo $VM_NAME | perl -pe  's/-(.*)/.*\1/'` | grep -v $VM_NAME| awk '{print $1}') && echo "NEW_DG_NAME: $NEW_DG_NAME"
}

3.4 Split the SRDF before starting.
------------------------------------
# Goal: just in cas we mess up the disk, we still have his copy
symrdf -g ${DG_NAME} suspend
symrdf -g ${DG_NAME} query

You will see the disks on “Suspended” state.


3.5 Linux, when adding a new disc, one need to recan the ost SCSI Bus.
-----------------------------------------------------------------------
# This step can be skipped if the disks have already been added

for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done

In the above command the the hyphens represent controller,channel,lun, so – – – indicates all controllers, all channels and all luns should be scanned.

3.6 Lun check.
---------------

On the 4 nodes, check which clusters (mercier or eufo) are in Read/Write :

multipath -ll | grep -A1 $VM_NAME

3.7 Get Old & New disks info.
------------------------------
{
echo "#==> disks in current disk group"
for i in {1..2}; do symdg -g $DG_NAME show ld DEV00$i | grep 'Device WWN'|sed -n 1p;done
echo "#==> disks in new disk group"
for i in {1..2}; do symdg -g $NEW_DG_NAME show ld DEV00$i | grep 'Device WWN'|sed -n 1p;done
}

3.8 Check that the disks are in RW state on the current node.
---------------------------------------------------------------
{
echo "#==> disks in current disk group $DG_NAME"
symdg -g $DG_NAME list ld ;echo
echo "#==> disks in new disk group $NEW_DG_NAME"
symdg -g $NEW_DG_NAME list ld ;echo
}


3.9 update the multipath config file.
--------------------------------------
# If this is not already done, add new disks to the multipath config file

On RW nodes, retrieve the LUNs currently used by the virtual machine in /etc/multipath.conf. 

grep -B1  $VM_NAME  /etc/multipath.conf | egrep 'wwid|alias' | perl -pe 's/(wwid.*$)\n/\1/'| awk '{print $NF,"("$2")"}'

Example:
[root@worf ~]# grep -B1  $VM_NAME  /etc/multipath.conf | egrep 'wwid|alias' | perl -pe 's/(wwid.*$)\n/\1/'| awk '{print $NF,"("$2")"}'
styleguide-tk_vmax3_t1_system1 (360000970000296700069533030343341)
styleguide-tk_vmax3_t1_data1 (360000970000296700069533030343342)


# save the old diks info for the storage retreive
--------------------------------------------------

multipath -ll | grep $VM_NAME | grep -v vmax3 | awk '{print $1,$2}'


# On the 4 nodes, add new LUNs in the multipath config & insert 'vmax3' in the alias name.
-------------------------------------------------------------------------------------------

vim /etc/multipath.conf

# Validate the syntax
---------------------
multipath -d -v 2

Check again.
-------------
grep -B1  $VM_NAME  /etc/multipath.conf | egrep 'wwid|alias' | perl -pe 's/(wwid.*$)\n/\1/'| awk '{print $NF,"("$2")"}'


3.10 Reload the lun config and check if the new disks are present.
-------------------------------------------------------------------

service multipathd reload


====================================================================================================================================
====================================================================================================================================
4. Copy the old disks to the new ones
====================================================================================================================================
====================================================================================================================================

Connect to the host where the vm is running:

4.1 Before starting the copy, check that the new disks sizes do match the old ones:

multipath -ll | grep -A1 $VM_NAME


4.2 Inform concerned people that the vm will be stopped for about 1 hour for the storage migration.
---------------------------------------------------------------------------------------------------

who=`who am i | awk '{print $1}'`
MAILTESTDEST=OPDL-INFRA-INT-TEST@publications.europa.eu
MAILPRODEST=OPDL-INFRA-INT-PROD@publications.europa.eu
MAILCC=OPDL-INFRA-SYSTEMS@publications.europa.eu,jean-claude.vallet@ext.publications.europa.eu,$who
MAILDEST=$MAILTESTDEST

{

The VM $VM_NAME will be OFFLINE for about one hour for storage migration.
} | mailx -s "$VM_NAME OFFLINE for storage migration" -r $who -c $MAILCC $MAILDEST

4.3 Stop the virtual machine :
-------------------------------
pcs status |grep $VM_NAME
pcs resource disable $VM_NAME && pcs status |grep $VM_NAME

# flush the data
sync
echo 3 > /proc/sys/vm/drop_caches

4.4 Test the variable VM_NAME:
-------------------------------
echo "${VM_NAME}_t1_system1 -> ${VM_NAME}_vmax3_t1_system1"
echo "${VM_NAME}_t1_data1   -> ${VM_NAME}_vmax3_t1_data1"

{
OLDDISKSYSTEM=/dev/mapper/${VM_NAME}_t1_system1        && ls -lh $OLDDISKSYSTEM
NEWDISKSYSTEM=/dev/mapper/${VM_NAME}_vmax3_t1_system1  && ls -lh $NEWDISKSYSTEM
OLDDISKDATA=/dev/mapper/${VM_NAME}_t1_data1            && ls -lh $OLDDISKDATA
NEWDISKDATA=/dev/mapper/${VM_NAME}_vamax3_t1_data1     && ls -lh $NEWDISKDATA
for D in $OLDDISKSYSTEM $NEWDISKSYSTEM $OLDDISKDATA $NEWDISKDATA; do
multipath -ll | grep -A1 `echo $D | sed 's:/dev/mapper/::'` | xargs| awk '{print $1,$5,$2,$3}' ;done
multipathd show maps format "%n %S %w %d %r" | egrep "name|$OLDDISKSYSTEM|$NEWDISKSYSTEM|$OLDDISKDATA|$NEWDISKDATA"
}


4.5 Copy the data:
-------------------

Note: 
The status=progress option is available as of GNU Coreutils 8.24+

[ `man dd | grep -c progress` -gt 0 ] && echo PROGRESS="status=progress" || PROGRESS=
echo "date && time dd if=$OLDDISKSYSTEM  of=$NEWDISKSYSTEM  bs=64K conv=noerror,sync $PROGRESS"
echo "date && time dd if=$OLDDISKDATA    of=$NEWDISKDATA    bs=64K conv=noerror,sync $PROGRESS"

OR (in case ddrescue is installaed)

echo "date && time ddrescue -f $OLDDISKSYSTEM $NEWDISKSYSTEM"
echo "date && time ddrescue -f $OLDDISKDATA   $NEWDISKDATA"

# Monitoring of the I/O
------------------------
iotop -p $(pgrep ^dd)

4.6 Check that we have the new devices partition 1 also (ie. system1 & system1p1; data1 & data1p1).
----------------------------------------------------------------------------------------------------

Check if they have the “p1” disk :
----------------------------------
ls -lh /dev/mapper/*$VM_NAME*
# Check if the p1 partitions do exist.
# If the p1 partitions don't exist, request the operating system to re-read the partition tables.
--------------------------------------------------------------------------------------------------
partprobe $NEWDISKSYSTEM
partprobe $NEWDISKDATA
And check again.
-----------------
ls -lh /dev/mapper/*$VM_NAME*

4.7 Edit the VM config file.
-----------------------------

ll /etc/libvirt/qemu/$VM_NAME.xml

grep "mapper/$VM_NAME"  /etc/libvirt/qemu/$VM_NAME.xml

virsh dumpxml $VM_NAME | egrep "$OLDDISKSYSTEM|$OLDDISKDATA"

# Get the old device names

Example:
[root@picard ~]# grep "mapper/$VM_NAME"  /etc/libvirt/qemu/$VM_NAME.xml
      <source dev='/dev/mapper/styleguide-tk_t1_system1p1'/>
      <source dev='/dev/mapper/styleguide-tk_t1_data1p1'/>

4.7.1 RedHat 7
----------------
Note: 
As of RedHat 7, the vm doesn't show up anymore when it is stopped.
In this case, we need to edit the vm config file & afterwrds define the vm.

vi /etc/libvirt/qemu/$VM_NAME.xml
OR
perl -pe "s:(/mapper/$VM_NAME)_:\1_vmax3_:" -i.bak /etc/libvirt/qemu/$VM_NAME.xml
\diff /etc/libvirt/qemu/$VM_NAME.xml.bak /etc/libvirt/qemu/$VM_NAME.xml

virsh dumpxml $VM_NAME | egrep "$NEWDISKSYSTEM|$NEWDISKDATA"

virsh define /etc/libvirt/qemu/$VM_NAME.xml

4.7.2 RedHat 6
----------------

virsh list | grep $VM_NAME

virsh edit $VM_NAME : change the device names (include "_vmax3" in the dev name)

4.7.3 check that the devices defined in the vm config file do exist
--------------------------------------------------------------------

for DEV in `virsh dumpxml $VM_NAME| grep mapper| awk -F"'" '{print $2}'`; do echo "#==> Checking $DEV" && ls -lh $DEV;done

Ex.
[root@iodine ~]# for DEV in `virsh dumpxml $VM_NAME| grep mapper| awk -F"'" '{print $2}'`; do echo "#==> Checking $DEV" && ls -lh $DEV;done
#==> Checking /dev/mapper/centreonbo2-pk_vmax3_t1_system1p1
lrwxrwxrwx 1 root root 9 Mar 13 12:30 /dev/mapper/centreonbo2-pk_vmax3_t1_system1p1 -> ../dm-124
#==> Checking /dev/mapper/centreonbo2-pk_vmax3_t1_data1p1
lrwxrwxrwx 1 root root 9 Mar 13 12:31 /dev/mapper/centreonbo2-pk_vmax3_t1_data1p1 -> ../dm-125


4.7.4 Copy the new vm config file on the three other nodes of the cluster.
-----------------------------------------------------------------------------

for node in `crm_node -p | sed "s/$(hostname -s)-cl//g"`; do echo -n "$node: " && virsh -c qemu+ssh://$node/system define /etc/libvirt/qemu/$VM_NAME.xml; done


4.8 Start the VM and check.
----------------------------
pcs resource enable $VM_NAME

# check boot progress:
virt-viewer --connect qemu+ssh:://iodine/system

pcs status |grep $VM_NAME
virsh list | grep $VM_NAME

# Post-check on the VM.
------------------------

ssh $VM_NAME
df -hlT
lsblk
dmesg
# if required, remove the fsck flag in fstab
cat /etc/fstab 


Centreon comment:


====================================================================================================================================
5. Cleanup: remove old disks
====================================================================================================================================

5.1 on the 4 nodes delete old entries in multipath.conf.
---------------------------------------------------------
Then you can comment or delete the multipath lines of the previous LUNs and do a service reload again :

ls -lh /dev/mapper/*${VM_NAME}*
cd /etc
vi multipath.conf
multipath -d -v 2
service multipathd reload

# Verify the old entries have been removed :

ls -lh /dev/mapper/*${VM_NAME}*

# if they still exist,  run the "removelun_rhel" script to delete the luns (for RHEL 6 only) :

removeluns=/home/admin/bin/removelun_rhel

# dry run
$removeluns $OLDDISKSYSTEM
# if ok, then execute the cmds
$removeluns $OLDDISKSYSTEM | bash

# dry run
$removeluns $OLDDISKDATA
# if ok, then execute the cmds
$removeluns $OLDDISKDATA | bash

# Check that the disks have been removed
ls -lh /dev/mapper/*${VM_NAME}*

5.2 Then when everything is ok, re-sync disks.
-----------------------------------------------

symrdf -g ${DG_NAME} establish

====================================================================================================================================
6. Inform people the migration is complete.
====================================================================================================================================

6.1. Send a mail to OPDL INFRA SYSTEMS <OPDL-INFRA-SYSTEMS@publications.europa.eu>; OPDL INFRA INT TEST <OPDL-INFRA-INT-TEST@publications.europa.eu>

who=`who am i | awk '{print $1}'`
MAILTESTDEST="OPDL-INFRA-INT-TEST@publications.europa.eu"
MAILPRODDEST="OPDL-INFRA-INT-PROD@publications.europa.eu"
MAILCC="OPDL-INFRA-SYSTEMS@publications.europa.eu,jean-claude.vallet@ext.publications.europa.eu"
# MAILDEST="$MAILTESTDEST,thomas.schmidt@ext.publications.europa.eu,Eric.CHOPPIN@ext.ec.europa.eu"
MAILDEST="$MAILTESTDEST,thomas.schmidt@ext.publications.europa.eu"

{
echo "

The storage migration of $VM_NAME has completed successfully, the server is back up and running.
"
} | mailx -s "Storage migration $VM_NAME" -r $who -c $MAILCC $MAILDEST


7.1 Open ticket to the storage to retrieve the old LUNs
--------------------------------------------------------

Open an SMT ticket to SBA-OP to recover the storage

[ -f "/sbin/crm_node" ] && IMPACTEDHOSTS=`crm_node -p| sed 's/-cl//g;s/ /,/g;s/,$//'` || IMPACTEDHOSTS=`hostname -s` && echo "#==> Impacted hosts: $IMPACTEDHOSTS"

{
echo -e "
#SMT Template: STORAGE REQUEST - Retrieve unused storage\n
#SMT Title: Recover storage for ${VM_NAME}\n
Type of storage: VMAX\n
Impacted hosts: $IMPACTEDHOSTS\n
Masking info (vm) : $VM_NAME\n
LUN WWN and/or ID:


"
} | mailx -s "create a ticket for $zone_name with this content" $who

