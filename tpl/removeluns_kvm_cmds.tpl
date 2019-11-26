Remove luns on cluster : <clustername>
----------------------------------------


------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------

VML=`echo "

" | xargs` && echo "VML=\"$VML\""

------------------------------------------------------------------------------------------------------------------------


========================================================================================================================

# Goto one host of the kvm cluster
VML="<vmlist>"
VMFILTER=`echo $VML|sed 's/ /|/g'` && echo $VMFILTER
CLUSTERNAME=<clustername>
# Check that the vm have been stopped
pcs status | egrep "$VMFILTER"
# Check for multipath errors
multipath -ll | egrep -i "failed|faulty" -B3 | egrep 'EMC|HITACHI' | sort
pvs

# Get the LUNs list on on node of the cluster
multipath -ll | egrep "$VMFILTER" | sort

# get nodes list
NODESLIST=`crm_node -p | sed "s/-cl//g"` && echo $NODESLIST

========================================================================================================================

========================================================================================================================

# open a terminal session on all 4 nodes of the cluster

# on each node of the cluster: remove the LUNs


VML="<vmlist>"
VMFILTER=`echo $VML|sed 's/ /|/g'` && echo $VMFILTER

multipath -ll | egrep "$VMFILTER" | sort
for LUN in `multipath -ll | egrep "$VMFILTER" | sort | cut -d" " -f1`; do echo /home/admin/bin/removelun_rhel $LUN;done
for LUN in `multipath -ll | egrep "$VMFILTER" | sort | cut -d" " -f1`; do /home/admin/bin/removelun_rhel $LUN|bash;done
multipath -ll | egrep "$VMFILTER"
multipath -ll | egrep -i "failed|faulty" -B3 | egrep 'EMC|HITACHI' | sort

========================================================================================================================

========================================================================================================================

Open an SMT ticket to SBA-OP to recover the storage

{
echo "
#SMT Template: STORAGE REQUEST - Retrieve unused storage
#SMT Title: Recover storage for ${CLUSTERNAME} - ${NODESLIST}
Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): vmax3 
Impacted hosts: ${NODESLIST}
Masking info (vm, datastore, zone,... name): ${VML}
LUN WWN and/or ID:
<luns>
"
}

========================================================================================================================

Ticket: 
========================================================================================================================

