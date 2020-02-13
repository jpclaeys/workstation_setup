====================================================================================================================================
====================================================================================================================================
====================================================================================================================================

# Save old disk info to create the ticket to storage team

multipath -ll | grep vmax_idol

multipathd show maps format "%n (%w)"| egrep idol

====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
# Start the copy
====================================================================================================================================

# Inform concerned people that the vm will be stopped for about 1 hour for the storage migration.
#--------------------------------------------------------------------------------------------------

VM_NAME=
who=`who am i | awk '{print $1}'`
MAILTESTDEST=OPDL-INFRA-INT-TEST@publications.europa.eu
MAILPRODEST=OPDL-INFRA-INT-PROD@publications.europa.eu
MAILCC=OPDL-INFRA-SYSTEMS@publications.europa.eu,jean-claude.vallet@ext.publications.europa.eu,$who
MAILDEST=$MAILTESTDEST

{
echo "

The VM $VM_NAME will be OFFLINE for about two hours for storage migration."
} | mailx -s "$VM_NAME OFFLINE for storage migration" -r $who -c $MAILCC $MAILDEST


# Define disk variables
{
OLDPREFIX=`ls -c1 /dev/mapper/*vmax_*$VM_NAME* | awk -F "/" '{print $NF;exit}' | sed "s/_${VM_NAME}.*//"` && echo $OLDPREFIX
NEWPREFIX=${OLDPREFIX}3 && echo $NEWPREFIX
OLDDISKSYSTEM=/dev/mapper/${OLDPREFIX}_${VM_NAME}_system1  && ls -lh $OLDDISKSYSTEM
NEWDISKSYSTEM=/dev/mapper/${NEWPREFIX}_${VM_NAME}_system1 && ls -lh $NEWDISKSYSTEM
OLDDISKDATA=/dev/mapper/${OLDPREFIX}_${VM_NAME}_data1      && ls -lh $OLDDISKDATA
NEWDISKDATA=/dev/mapper/${NEWPREFIX}_${VM_NAME}_data1     && ls -lh $NEWDISKDATA
for D in $OLDDISKSYSTEM $NEWDISKSYSTEM $OLDDISKDATA $NEWDISKDATA; do
multipath -ll | grep -A1 `echo $D | sed 's:/dev/mapper/::'` | xargs| awk '{print $1,$5,$2,$3}' ;done
multipathd show maps format "%n %S %w %d %r" | egrep "name|$OLDDISKSYSTEM|$NEWDISKSYSTEM|$OLDDISKDATA|$NEWDISKDATA"
}


ls -lh /dev/mapper/*vmax_*$VM_NAME*
ls -lh /dev/mapper/*vmax3*$VM_NAME*

virsh list | grep $VM_NAME

sync && echo 3 > /proc/sys/vm/drop_caches

echo virsh shutdown $VM_NAME

# Wait until the VM is down
virsh list

{
[ `man dd | grep -c progress` -gt 0 ] && echo PROGRESS="status=progress" || PROGRESS=
echo "date && time dd if=$OLDDISKSYSTEM  of=$NEWDISKSYSTEM  bs=64K conv=noerror,sync $PROGRESS"
echo "date && time dd if=$OLDDISKDATA    of=$NEWDISKDATA    bs=64K conv=noerror,sync $PROGRESS"
}

{
echo partprobe $NEWDISKSYSTEM
echo partprobe $NEWDISKDATA
}

ls -lh /dev/mapper/*vmax3*$VM_NAME*

# Change the device name for te VM

virsh dumpxml $VM_NAME | grep mapper
virsh dumpxml $VM_NAME | egrep "$OLDDISKSYSTEM|$OLDDISKDATA"
virsh edit $VM_NAME
virsh dumpxml $VM_NAME | egrep "$NEWDISKSYSTEM|$NEWDISKDATA"

for DEV in `virsh dumpxml $VM_NAME| grep mapper| awk -F"'" '{print $2}'`; do echo "#==> Checking $DEV" && ls -lh $DEV;done

# Restart the VM
virsh start $VM_NAME

virsh list


# Checking startup of the VM

virsh console $VM_NAME

lsblk
df -hlT
dmesg

Note: 
Exit from console on French keyboard: CTRL+SHIFT+5  (EquiV. to ^] on English keyboard).

------------------------------------------------------------------------------------------------------------------------------------


====================================================================================================================================
5. Cleanup: remove old disks
====================================================================================================================================

5.1 delete old entries in multipath.conf.
------------------------------------------
Then you can comment or delete the multipath lines of the previous LUNs and do a service reload again :

ls -lh /dev/mapper/*${VM_NAME}*

vi multipath.conf

multipath -d -v 2

service multipathd reload

# Verify the old entries have been removed :

ls -lh /dev/mapper/*${VM_NAME}*

# if they still exist,  run the "removelun_rhel" script to delete the luns (for RHEL 6 only) :

removeluns=/home/admin/bin/removelun_rhel

OLDDISKSYSTEMSHORT=`echo $OLDDISKSYSTEM | awk -F"/" '{print $NF}'`
OLDDISKDATASHORT=`echo $OLDDISKDATA | awk -F"/" '{print $NF}'`
# dry run
$removeluns $OLDDISKSYSTEMSHORT
# if ok, then execute the cmds
$removeluns $OLDDISKSYSTEMSHORT | bash

# dry run
$removeluns $OLDDISKDATASHORT
# if ok, then execute the cmds
$removeluns $OLDDISKDATASHORT | bash

# Check that the disks have been removed
ls -lh /dev/mapper/*${VM_NAME}*


====================================================================================================================================
6. Inform people the migration is complete.
====================================================================================================================================

6.1. Send a mail to OPDL INFRA SYSTEMS <OPDL-INFRA-SYSTEMS@publications.europa.eu>; OPDL INFRA INT TEST <OPDL-INFRA-INT-TEST@publications.europa.eu>

who=`who am i | awk '{print $1}'`
MAILTESTDEST="OPDL-INFRA-INT-TEST@publications.europa.eu"
MAILPRODDEST="OPDL-INFRA-INT-PROD@publications.europa.eu"
MAILCC="OPDL-INFRA-SYSTEMS@publications.europa.eu,jean-claude.vallet@ext.publications.europa.eu"
MAILDEST="$MAILTESTDEST,thomas.schmidt@ext.publications.europa.eu,Eric.CHOPPIN@ext.ec.europa.eu"
#MAILDEST="$MAILTESTDEST,thomas.schmidt@ext.publications.europa.eu"

{
echo "

The storage migration of $VM_NAME has completed successfully, the server is back up and running.
"
} | mailx -s "Storage migration $VM_NAME" -r $who -c $MAILCC $MAILDEST


7.1 Open ticket to the storage to retrieve the old LUNs
--------------------------------------------------------

Open an SMT ticket to SBA-OP to recover the storage

[ -f "/sbin/crm_node" ] && IMPACTEDHOSTS=`crm_node -p| sed 's/-cl//g;s/ /,/g;s/,$//'` || IMPACTEDHOSTS=`hostname -s` && echo "#==> Impacted hosts: $IMPACTEDHOSTS"
VMLIST=`virsh list| awk '/running/ {print $2}'| xargs|sed 's/ /, /'` && echo "#==> VM list: $VMLIST"

{
echo -e "
#SMT Template: STORAGE REQUEST - Retrieve unused storage\n
#SMT Title: Recover storage for ${VMLIST}\n
Type of storage: VMAX\n
Impacted hosts: $IMPACTEDHOSTS\n
Masking info (vm) : $VMLIST\n
LUN WWN and/or ID:

TBD

"
} | mailx -s "create a ticket for $VMLIST with this content" $who

Ticket: 

