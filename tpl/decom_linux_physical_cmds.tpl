decom linux physical server - <hostname>
-----------------------------------------

====================================================================================================================================

goto to opvmwstsx11

# Mail to monitoring:
----------------------

{
cat <<EOT
Bonjour,

Voulez-vous supprimer les clients suivants du monitoring:
<hostname>

EOT
} | mailx -s "Remove <hostname> from the monitoring" -r $email -c $email,OPDL-INFRA-INT-PROD@publications.europa.eu,op-helpdesk@publications.europa.eu OP-IT-PRODUCTION.europa.eu
====================================================================================================================================

====================================================================================================================================

# Open a ticket to delete the backup client
--------------------------------------------

CLIENT=bkp-<hostname> && echo $CLIENT
{
echo "#SMT Title: Remove backup client for $CLIENT"
echo "#SMT Template: BACKUP REQUEST - Delete client"
echo
echo Client name: $CLIENT
echo OS: Linux
echo Reason: server removed
} | mailx -s "create a ticket with this content - delete backup client for $CLIENT" $email

====================================================================================================================================

Ticket: 

====================================================================================================================================
Open a session On the host
====================================================================================================================================

# Fetch info about the Hosts
------------------------------
{
HOST=`uname -n | cut -d'.' -f1` && echo $HOST
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/$HOST
[ ! -d "$TMP_FOLDER" ] && mkdir $TMP_FOLDER

# Create the sysinfo file (from cmdb)
. ~claeyje/bin/set_decom_linux_vars.sh 
save_decom_linux_vars $HOST

# Save HBS WWN's
cat /sys/class/fc_host/host?/port_name | tee $TMP_FOLDER/hba_wwns_${HOST}.txt

# Save /etc/hosts
cat /etc/hosts | tee $TMP_FOLDER/etc_hosts_${HOST}

# Save IP info
ip a > $TMP_FOLDER/ip_config_${HOST}.txt

# Get luns
# rescan the SCSI bus
for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done
multipath -ll | egrep 'EMC|HITACHI' | sort | tee $TMP_FOLDER/LUNs_${HOST}.txt

# System product name
(dmidecode -s system-manufacturer && dmidecode -s system-product-name )| xargs | tee $TMP_FOLDER/product_name_${HOST}.txt

# List $TMP_FOLDER content
ls -lh $TMP_FOLDER
}

{
# Remove the luns if any
#------------------------

for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort | awk '{print $1}'`; do echo "/home/admin/bin/removelun_rhel $LUN | bash";done
for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort | awk '{print $1}'`; do /home/admin/bin/removelun_rhel $LUN | bash ;done

# Check: all LUNs are gone
#--------------------------
multipath -ll | egrep -c 'EMC|HITACHI' 
}

====================================================================================================================================

====================================================================================================================================
# Create ticket for storage: retrieve storage
----------------------------------------------
{
echo "#SMT Template: STORAGE REQUEST - Retrieve unused storage"
echo "#SMT Title: Recover storage for $HOST"
echo "Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): VMAX"
echo "Impacted hosts: $HOST"
echo "Masking info (vm, datastore, zone,... name): $HOST"
echo "LUN WWN and/or ID:"
<luns>
}

====================================================================================================================================

Ticket:

====================================================================================================================================
# Remove the masking/zoning
----------------------------
Execute these commands on the host

# define variables if they are not set yet
HOST=`uname -n | cut -d'.' -f1` && echo $HOST

{
cat <<EOT
# Template: STORAGE REQUEST - Change masking
# Title: Removal of zoning and masking for $HOST
Impacted host: $HOST
HBA-PORTS Impacted devices:
`cat /sys/class/fc_host/host?/port_name`

Reason: Client is going to be decommissioned

Best regards
EOT
}

===================================================================================================================================

Ticket:

====================================================================================================================================

Remove the server from satellite
---------------------------------
If you have the necessary rights go to satellite page https://satellite-pk search for the server and the right site you will have a click button

Opsatellite WebGUI
Goto Hosts
enter <hostname> in the search window 
Select the host
In the edit drop down menu select delete
confirm

====================================================================================================================================
====================================================================================================================================
Retrieve information for later
-------------------------------
Recover the ip address

Retrieve address for the service processor:

export ILO=`/home/admin/bin/getcmdb.sh cons | grep ${HOST}-sc | awk '{print $1}' | cut -f 1 -d ";"` && echo $ILO
====================================================================================================================================


====================================================================================================================================


====================================================================================================================================
====================================================================================================================================
!!!!!!!!!! Wait until the storage finishes the cleanup (retrieve luns if any and remove masking) !!!!!!!!!!
====================================================================================================================================
====================================================================================================================================


====================================================================================================================================

# Shutdown the server
----------------------
shutdown -h now
OR
poweroff

====================================================================================================================================
Network: Remove IP and DNS entry for the server 
------------------------------------------------

Connect to http://resop/ip and fill in the form

- enter the hosts
- enter the CNAME

HOST=<hostname>
CNAME=

# Hosts IP @
printf "%-12s: " $HOST && dig ${HOST}.opoce.cec.eu.int +short

# Create the excel request file (template: OPS-RFC-DNS-delete.xltx)
generate_ip_delete_hostlist_records $HOST $CNAME | tee ~/snet/data.txt

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $HOST $CNAME

====================================================================================================================================

====================================================================================================================================

Wipe the disks
---------------

Boot with the ISO using “Image file CD/DVD-ROM”.

Use Darik’s Boot And Nuke (DBAN) tool "dban-2.3.0_i586.iso"

DBAN is a very well known and respected data wiping tool that runs from a bootable disc and is great for when you want to sanitize more than a single drive or system drive because it can automatically erase all found partitions.

Burn the ISO to CD or create a bootable USB stick and boot to DBAN. Press Enter at the prompt to be taken to interactive mode where you choose your settings.

If you type autonuke at the prompt, IT WILL ERASE ALL DRIVES WITHOUT CONFIRMATION, so is something you should be very careful with.

Read More: https://www.raymond.cc/blog/wipe-your-hard-disk-before-lending-or-giving-away/


Method: DoD Short

Erase sda

Connect to the system console via http://<hostname>-sc
Note:
On Lenovo IMM II   (ex. X3850)
Server Management / Remote Control
Virtual Media Mounted from URL
Click on mount
select the ISO image

Remote Control
check "Use the java Client"
Start remote control in single-user mode

On the console:
---------------
Tools / Launch Virtual Media 
Add Image
Select the image on exchange/claeyje/dban-2.3.0_i586.iso
Check "Map" to select the image
Mount Selected

Tools / Power / Power On The Server Immediately
boot: autonuke


====================================================================================================================================
Poweroff the server
--------------------

Console( ILO 4)
Power Switch
Press and Hold



====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
===============================================  STOP here if this is a blade  =====================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================

====================================================================================================================================
Reset the consoles to factory defaults
---------------------------------------

Note: 
For Blades, we need to ask the Windows OP team

Resetting the IMM2 to the factory defaults
--------------------------------------------

Select the "IMM Management" tab
Select the "IMM Configuration" tab
Select the "Reset IMM to factory defaults" option
Confirm Reset to factory defaults

====================================================================================================================================
====================================================================================================================================
Network: Remove IP and DNS entry for the server, the bkp and the consoles
---------------------------------------------------------------------------

Connect to http://resop/ip and fill in the form

- enter the hosts
- enter the bkp-hosts
- enter the consoles

# send the request

OR

# Use a script to generate the Excel file contents
#----------------------------------------------------
{
# view the IP @
for H in <hostname> bkp-<hostname> <hostname>-sc; do printf "%-12s: " $H && dig ${H}.opoce.cec.eu.int +short;done

HL="<hostname> <hostname>-sc"

# Create the excel request file
generate_ip_delete_hostlist_records $HL | tee ~/snet/data.txt

# On Windows, create a new excel sheet based on the "OPS-RFC-DNS-RF2.3-delete.xltx" template
# run the DNS_delete_entry macro

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $HL $CONSL
}

====================================================================================================================================

Ticket:
====================================================================================================================================
Inform the CMDB manager about remove
-------------------------------------

HOST=<hostname> && echo $HOST
{
cat << EOT
Dear all,

Please change the status of the nodes:

`cat /net/nfs-infra.isilon/unix/systemstore/temp/${HOST}/sysinfo_${HOST}.txt`

to

MODE: REMOVED/ARCHIVED.

Best regards
EOT
} | mailx -s "Change CMDB for ${HOST} to archived" -r $email -c $email OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu


====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================

DCF-OP : Server can be unwired
-------------------------------

Create an SMT Ticket and assign it to DCF-OP for unwiring
----------------------------------------------------------

One ticket per Datacenter

# Define MER hosts
HOST=<hostname>

{
cat << EOT

# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Unwire ${HOST}

Dear all,

Please unwire the following systems from the infrastructure:

`cat /net/nfs-infra.isilon/unix/systemstore/temp/${HOST}/sysinfo_${HOST}.txt`

will be removed from the rack

Best regards
EOT
}

Ticket:

----------------------------------------------------------------------------
# Define EUFO hosts
--------------------
HOST=<hostname>

{
cat << EOT

# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Unwire ${HOST}

Dear all,

Please unwire the following systems from the infrastructure:

`cat /net/nfs-infra.isilon/unix/systemstore/temp/${HOST}/sysinfo_${HOST}.txt`

will be removed from the rack

Best regards
EOT
}

Ticket

====================================================================================================================================

====================================================================================================================================

Create a second SMT ticket, assigned to DCF-OP for the physical remove
------------------------------------------------------------------------
Create one ticket per datacenter !

# Define EUFO hosts
HOST=<hostname>
{
cat << EOT
# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Remove ${HOST} physically

Dear all,

please remove the following systems physically:

`cat /net/nfs-infra.isilon/unix/systemstore/temp/${HOST}/sysinfo_${HOST}.txt`

has order to be disconnected and can now remove from rack.

Best regards

EOT
}

Ticket:

# Define EUFO hosts
--------------------
{
cat << EOT
# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Remove ${HOST} physically

Dear all,

please remove the following systems physically:

`cat /net/nfs-infra.isilon/unix/systemstore/temp/${HOST}/sysinfo_${HOST}.txt`

has order to be disconnected and can now remove from rack.

Best regards

EOT
}

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
