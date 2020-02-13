decom kvm cluster <clustername>
----------------------------------------------------------------
====================================================================================================================================

====================================================================================================================================



====================================================================================================================================

CLUSTER=<clustername>
HL=`eval $CLUSTER` && echo $HL

====================================================================================================================================

goto to opvmwstsx11
CLUSTER=<clustername>
HL=`eval $CLUSTER` && echo $HL

====================================================================================================================================
# Mail to monitoring:
----------------------

{
cat <<EOT
Bonjour,

Voulez-vous supprimer les clients suivants du monitoring:
$HL

EOT
} | mailx -s "Remove $HL from the monitoring" -r $email -c $email,OPDL-INFRA-INT-PROD@publications.europa.eu OP-IT-PRODUCTION@publications.europa.eu

====================================================================================================================================
# Open a ticket to delete the backup client
--------------------------------------------

CLIENTS=`for H in $HL; do echo "bkp-${H}";done|xargs` && echo $CLIENTS
{
echo "#SMT Title: Remove backup clients for $CLIENTS"
echo "#SMT Template: BACKUP REQUEST - Delete clients"
echo
echo Client names: $CLIENTS
echo OS: Linux
echo Reason: vms removed
} | mailx -s "create a ticket with this content" $email

====================================================================================================================================

Ticket: 
====================================================================================================================================

====================================================================================================================================
Open a session On all 4 servers 
====================================================================================================================================

# Fetch info about the Hosts
------------------------------
HOST=`uname -n | cut -d'.' -f1`
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/${HOST}
[ ! -d "$TMP_FOLDER" ] && mkdir $TMP_FOLDER

# Create the sysinfo file (from cmdb)
save_decom_linux_vars

# Save HBS WWN's
cat /sys/class/fc_host/host?/port_name | tee $TMP_FOLDER/hba_wwns_${HOST}.txt

# Save /etc/hosts
cat /etc/hosts | tee $TMP_FOLDER/etc_hosts_$HOST

# Save IP info
ip a > tee $TMP_FOLDER/ip_config_${HOST}.txt

# Get luns
------------
# rescan the SCSI bus
for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done
# Get the luns
multipath -ll | egrep 'EMC|HITACHI'  | sort | tee $TMP_FOLDER/LUNs_${HOST}.txt

# List $TMP_FOLDER content
ls -lh $TMP_FOLDER

On all 4 servers remove the luns
---------------------------------

for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort | awk '{print $1}'`; do echo "/home/admin/bin/removelun_rhel $LUN | bash";done
for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort | awk '{print $1}'`; do /home/admin/bin/removelun_rhel $LUN | bash ;done

# Check: all LUNs are gone
multipath -ll | egrep -c 'EMC|HITACHI' 

====================================================================================================================================
# Create ticket for storage: retrieve storage
----------------------------------------------
{
echo "#SMT Template: STORAGE REQUEST - Retrieve unused storage"
echo "#SMT Title: Recover storage for $CLUSTER - $HL"
echo "Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): VMAX"
echo "Impacted hosts: $HL"
echo "Masking info (vm, datastore, zone,... name): $HL"
echo "LUN WWN and/or ID:"
<luns>
}
====================================================================================================================================

Ticket:
====================================================================================================================================
# Remove the masking/zoning
----------------------------
Execute these commands on the 4 nodes of the cluster
{
echo "Impacted host: `hostname`"
echo -n "IP Address: " && dig `hostname`.opoce.cec.eu.int +short && echo -n "OS: " && cat /etc/system-release
Manufacturer=`dmidecode -t system | awk -F":" '/Manufacturer:/ {print $NF}'` && Model=`dmidecode -t system | awk -F":" '/Product Name:/ {print $NF}'` && echo "MODEL:$Manufacturer -$Model"
echo "HBA-PORTS Impacted devices:"
cat /sys/class/fc_host/host?/port_name
echo
}


# Goto opvmwstsx11
------------------
# define variables if they are not set yet
echo $CLUSTER
echo $HL

# Insert the ouput of the above command on the 4 hosts to the following text:

{
cat <<EOT
# Template: STORAGE REQUEST - Change masking
# Title: Removal of zoning and masking for $CLUSTER - $HL

<insert here>

Reason: Clients are going to be decommissioned

EOT
}

====================================================================================================================================

Ticket: 
====================================================================================================================================

====================================================================================================================================

3.2.1.3 Remove the servers from satellite
-------------------------------------------
If you have the necessary rights go to satellite page https://satellite-pk search for the server and the right site you will have a click button

Opsatellite WebGUI
Goto Hosts
enter <clustername> in the search window --> the 4 hosts will show up
Select all hosts
Select Action drop down menu: delete
Submit

====================================================================================================================================
3.2.2 Retrieve information for later
Recover the ip address

Retrieve address for the service processor:

export ILO=`/home/admin/bin/getcmdb.sh cons | grep $(uname -n | cut -d'.' -f1) | awk '{ print $1}' | cut -f 1 -d ";"` && echo $ILO
====================================================================================================================================




====================================================================================================================================


====================================================================================================================================
====================================================================================================================================
!!!!!!!!!! Wait until the storage finishes the cleanup (retrieve luns if any and remove masking) !!!!!!!!!!
====================================================================================================================================
====================================================================================================================================


====================================================================================================================================

# Shutdown all 4 servers
-------------------------
shutdown -h now
OR
poweroff

====================================================================================================================================
====================================================================================================================================

3.2.3 Wipe the disks
---------------------

Boot with the ISO using “Image file CD/DVD-ROM”.

Use Darik’s Boot And Nuke (DBAN) tool "dban-2.3.0_i586.iso"

DBAN is a very well known and respected data wiping tool that runs from a bootable disc and is great for when you want to sanitize more than a single drive or system drive because it can automatically erase all found partitions.

Burn the ISO to CD or create a bootable USB stick and boot to DBAN. Press Enter at the prompt to be taken to interactive mode where you choose your settings.

If you type autonuke at the prompt, IT WILL ERASE ALL DRIVES WITHOUT CONFIRMATION, so is something you should be very careful with.

Read More: https://www.raymond.cc/blog/wipe-your-hard-disk-before-lending-or-giving-away/


Method: DoD Short

Erase sda


Note:
On Lenovo IMM II   (ex. X3850)
Server Management / Remote Control
Virtual Media Mounted from URL
Click on mount
select the ISO image

Remote Control
check "Use the java Client"
Start remote control in single-user mode

On the console
Virtual Media / Activate
Tools / Power / Power On The Server Immediately
boot: autonuke

====================================================================================================================================
Poweroff the server
--------------------

Console( ILO 4)
Power Switch
Press and Hold


====================================================================================================================================
Reset the consoles to factory defaults
---------------------------------------

Resetting the IMM2 to the factory defaults
--------------------------------------------

Select the "IMM Management" tab
Select the "IMM Configuration" tab
Select the "Reset IMM to factory defaults" option
Confirm Reset to factory defaults


====================================================================================================================================
3.3.2 Network: Remove IP and DNS entry for the server, the bkp and the consoles
---------------------------------------------------------------------------------

Connect to http://resop/ip and fill in the form

- enter the hosts
- enter the bkp-hosts
- enter the consoles

{
HL=`eval $CLUSTER` && echo $HL
CONSL=`for H in $HL; do echo ${H}-sc;done|xargs` && echo $CONSL
# Hosts IP @
for H in $HL; do printf "%-12s: " $H && dig ${H}.opoce.cec.eu.int +short;done
# backup IP @
for H in $HL; do printf "%-12s: " bkp-${H} && dig bkp-${H}.opoce.cec.eu.int +short;done
# Consoles IP @
for H in $CONSL; do printf "%-12s: " ${H} && dig ${H}.opoce.cec.eu.int +short;done
}

# Create the excel request file 
generate_ip_delete_hostlist_records $HL $CONSL | tee ~claeyje/snet/data.txt

# On Windows, create a new excel sheet based on the "OPS-RFC-DNS-RF2.3-delete.xltx" template
run DNS_delete_entry macro

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $HL $CONSL

====================================================================================================================================

Ticket:
====================================================================================================================================

====================================================================================================================================
3.3.5 Inform the CMDB manager about remove
-------------------------------------------

HL=""
{
cat << EOT

Please change the status of the nodes:

`for H in $HL; do cat /net/nfs-infra.isilon/unix/systemstore/temp/${H}/sysinfo_${H}.txt;done`

to

MODE: REMOVED/ARCHIVED.




EOT
} | mailx -s "Change CMDB for ${HL} to archived" -r $email -c $email OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu


====================================================================================================================================

====================================================================================================================================

====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
===================================   STOP here if physical remove will be done later on   =========================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================





====================================================================================================================================
3.3.4 DCF-OP : Server can be unwired
-------------------------------------
Create an SMT Ticket and assign it to DCF-OP for unwiring

One ticket per Datacenter

# Define MER hosts
-------------------
HL=""

{
cat << EOT

# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Unwire ${HL}


Please unwire the following systems from the infrastructure:

`for H in $HL; do cat /net/nfs-infra.isilon/unix/systemstore/temp/${H}/sysinfo_${H}.txt;done`

will be removed from the rack

EOT
}

====================================================================================================================================

Ticket:
====================================================================================================================================

# Define EUFO hosts
--------------------
HL=""

{
cat << EOT

# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Unwire ${HL}


Please unwire the following systems from the infrastructure:

`for H in $HL; do cat /net/nfs-infra.isilon/unix/systemstore/temp/${H}/sysinfo_${H}.txt;done`

will be removed from the rack

EOT
}

====================================================================================================================================

Ticket: 
====================================================================================================================================

====================================================================================================================================

Create a second SMT ticket, assigned to DCF-OP for the physical remove:
Create one ticket per datacenter !

# Define MER hosts
-------------------
HL=""
{
cat << EOT
# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Remove ${HL} physically


Please remove the following system physically:

`for H in $HL; do cat /net/nfs-infra.isilon/unix/systemstore/temp/${H}/sysinfo_${H}.txt;done`

must be disconnected and can now be removed from the rack.


EOT
}

====================================================================================================================================

Ticket:
====================================================================================================================================

# Define EUFO hosts
--------------------
HL=`eval $CLUSTER` && echo $HL
{
cat << EOT
# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Remove ${HL} physically


Please remove the following system physically:

`for H in $HL; do cat /net/nfs-infra.isilon/unix/systemstore/temp/${H}/sysinfo_${H}.txt;done`

must be disconnected and can now be removed from the rack.


EOT
}
====================================================================================================================================

Ticket:
====================================================================================================================================
====================================================================================================================================

====================================================================================================================================

====================================================================================================================================

====================================================================================================================================

====================================================================================================================================

====================================================================================================================================

====================================================================================================================================
====================================================================================================================================
