decom_vm
====================================================================================================================================


====================================================================================================================================


====================================================================================================================================
====================================================================================================================================
VML="<vmlist>"
CLUSTERNAME=<clustername>
KVM_HOST=
# Goto one node of the cluster
NODESLIST=`crm_node -p | sed "s/-cl//g"` && echo $NODESLIST
====================================================================================================================================
====================================================================================================================================
1. Fetch info about the VMs
VML="<vmlist>"
{
for H in $VML; do echo -e "\n# ===> $H  info <===\n"
echo "# --> IP@"                && dig ${H}.opoce.cec.eu.int +short
echo "# --> system-release"     && ssh $H cat /etc/redhat-release
echo "# --> hosts"              && ssh $H cat /etc/hosts
# echo "# --> IP config"          && ssh $H ip a
done
}

====================================================================================================================================

====================================================================================================================================
2. stop monitoring

VML="<vmlist>"
{
cat <<EOT
Bonjour,

Voulez-vous supprimer les clients suivants du monitoring:
$VML
EOT
} | mailx -s "Remove $VML from the monitoring" -r $email -c $email,OPDL-INFRA-INT-PROD@publications.europa.eu,op-helpdesk@publications.europa.eu OP-IT-PRODUCTION.europa.eu


====================================================================================================================================

====================================================================================================================================
3. Open an SMT ticket to SBA-OP to remove the backup client

VML="<vmlist>"
CLIENTS=`for H in $VML; do echo "bkp-${H}";done|xargs` && echo $CLIENTS
{
cat <<EOT
#SMT Title: Remove backup clients for $CLIENTS
#SMT Template: BACKUP REQUEST - Delete client

Client names: $CLIENTS
OS: Red Hat Enterprise Linux Server release 6.9 (Santiago)
Reason: vms removed
EOT
} | mailx -s "create a ticket with this content" $email

====================================================================================================================================

Ticket:
====================================================================================================================================

4. Stop the VMs
----------------

Goto one of the cluster hosts

VML="<vmlist>"
VMFILTER=`echo $VML|sed 's/ /|/g'` && echo $VMFILTER
CLUSTERNAME=<clustername>

# If PCS cluster
-----------------
pcs status | egrep "$VMFILTER"

for H in $VML; do echo "pcs resource disable $H";done
# Wait until the vms are stopped
pcs status | egrep "$VMFILTER"
for H in $VML; do echo "pcs resource unmanage $H";done
pcs status | egrep "$VMFILTER"

# if KVM cluster (no cluster)
------------------------------

virsh list --all

for H in $VML; do echo virsh shutdown $H; done

virsh list --all


====================================================================================================================================

====================================================================================================================================


====================================================================================================================================
Find the LUNs
--------------

VML="<vmlist>"
VMFILTER=`echo $VML|sed 's/ /|/g'` && echo $VMFILTER
CLUSTERNAME=<clustername>

multipath -ll | egrep "$VMFILTER" | sort
for LUN in `multipath -ll | egrep "$VMFILTER" | sort | cut -d" " -f1`; do echo /home/admin/bin/removelun_rhel $LUN;done
for LUN in `multipath -ll | egrep "$VMFILTER" | sort | cut -d" " -f1`; do /home/admin/bin/removelun_rhel $LUN|bash;done
multipath -ll | egrep "$VMFILTER"
multipath -ll | egrep -i "failed|faulty" -B3 | egrep 'EMC|HITACHI' | sort
====================================================================================================================================

====================================================================================================================================

====================================================================================================================================
Step 13. Open an SMT ticket to SBA-OP to recover the storage

VML="<vmlist>"
NODESLIST=`crm_node -p | sed "s/-cl//g"` && echo $NODESLIST
{
cat <<EOT
#SMT Template: STORAGE REQUEST - Retrieve unused storage
#SMT Title: Recover storage for ${NODESLIST} - ${VML}
Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): vmax3
Impacted hosts: ${NODESLIST}
Masking info (vm, datastore, zone,... name): ${VML}
LUN WWN and/or ID:
EOT
}

====================================================================================================================================

Ticket:
====================================================================================================================================

Step 14: Return Network / DNS (Create SMT ticket)

https://resop/ip/add_is.php

- IP
- bkp-${IP}
- alias(es) (ops...)

VML="<vmlist>"
CNAMEL=         # CNAMES list

# Create the excel request file (template: OPS-RFC-DNS-delete.xltx)
generate_ip_delete_hostlist_records $VML $CNAMEL| tee ~/snet/data.txt

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $VML $CNAMEL


====================================================================================================================================

Ticket:
====================================================================================================================================
Step 15: Delete the host from Satellite (WEB interface)
https://satellite-pk/hosts?utf8=%E2%9C%93&search=<hostname> delete host

Goto the Satellite WebGUI
type idoltmp in the search box
select all vms
Select Action drop down menu: delete

====================================================================================================================================

Step 17: remove the vms from CMDB (Create an EMAIL)

{
VML="<vmlist>"
echo "The vms $VML have been decommissioned; they can be removed from the CMDB."
} | mailx -s "Update the CMDB: ${zone_name}" -r $email -c $email OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu

====================================================================================================================================


