decom linux physical server - <hostname>
-----------------------------------------

====================================================================================================================================
# Open ticket to remove the monitoring:
----------------------------------------

Incident type: REQUEST FOR SERVICE
Configuration item: SERVER
System: HARDWARE AND OPERATING SYSTEMS
Component: SERVERS

{
cat <<EOT
# Title:
REMOVE MONITORING: <hostname>

# Description:

Servers list: <hostname>
Action: Stop monitoring
EOT
}

TO:  IT-PRODUCTION-OP
------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
# Open a ticket to delete the backup client
--------------------------------------------

{
cat <<EOT
#SMT Title: Remove backup client for bkp-<hostname>
#SMT Template: BACKUP REQUEST - Delete client

Client name: bkp-<hostname>
OS: Linux
Reason: server removed
EOT
}

TO: SBA-OP
------------------------------------------------------------------------------------------------------------------------------------
Ticket: 
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
Open a session On the host
====================================================================================================================================

# Fetch info about the Hosts
------------------------------
!!!!! Note: /net/nfs-infra.isilon/unix/systemstore is only visible from opvmwstsx11 !!!!!

{
msg "Define the TMP folder"
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
[ ! -d "$TMP_FOLDER" ] && mkdir $TMP_FOLDER
echo $TMP_FOLDER

# Create the sysinfo file (from cmdb)
msg "Create the sysinfo file (from cmdb)"
save_decom_linux_vars

# Save HBS WWN's
msg "Save HBS WWN's"
cat /sys/class/fc_host/host?/port_name | tee $TMP_FOLDER/hba_wwns_<hostname>.txt

# Save /etc/hosts
msg "Save /etc/hosts"
cat /etc/hosts | tee $TMP_FOLDER/etc_hosts_<hostname>.txt

# Save IP info
msg "Save IP info"
ip a > $TMP_FOLDER/ip_config_<hostname>.txt

# Get luns
msg "Get luns"
# rescan the SCSI bus
for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done
multipath -ll | egrep 'EMC|HITACHI' | sort | tee $TMP_FOLDER/LUNs_<hostname>.txt

# System product name
msg "System product name"
(dmidecode -s system-manufacturer && dmidecode -s system-product-name )| xargs | tee $TMP_FOLDER/product_name_<hostname>.txt

msg "TMP_FOLDER content"
# List $TMP_FOLDER content
ls -lh $TMP_FOLDER
}

------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------

{
# Remove the luns if any
#------------------------
# rescan the SCSI bus
for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done

# Try removal by using the removelun_rhel script (Requires Switch.pm module for perl)
[ ! -f "/usr/share/perl5/Switch.pm" ] && errmsg "Perl Switch.pm module is missing"
for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort | awk '{print $1}'`; do echo "/home/admin/bin/removelun_rhel $LUN | bash";done
for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort | awk '{print $1}'`; do /home/admin/bin/removelun_rhel $LUN | bash ;done

# removelun_rhel doesn't work, do it manually
{
multipath -ll | grep 3600
DEVLIST=`multipath -ll | grep running | awk '{print $(NF-4)}' ` && echo $DEVLIST
DEVALIAS=`multipath -ll | grep EMC | awk '{print $1}' ` && echo $DEVALIAS
#for i in $DEVALIAS; do echo multipath -f /dev/mapper/${i}P1;done | bash   # for i in $DEVALIAS; do echo multipath -f /dev/mapper/$i;done | bash
for i in $DEVALIAS; do echo multipath -f /dev/mapper/$i;done | bash
for i in $DEVLIST; do echo "echo offline > /sys/block/$i/device/state"; echo "echo 1 >/sys/block/$i/device/delete" ;done | bash
multipath -ll
}


# Check: all LUNs are gone
#--------------------------
multipath -ll | egrep -c 'EMC|HITACHI' 
}

====================================================================================================================================

====================================================================================================================================
# Create ticket for storage: retrieve storage
----------------------------------------------

{
cat <<EOT
#SMT Template: STORAGE REQUEST - Retrieve unused storage
#SMT Title: Recover storage for <hostname>
Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): VMAX
Impacted hosts: <hostname>
Masking info (vm, datastore, zone,... name): <hostname>
LUN WWN and/or ID:
`cat $TMP_FOLDER/LUNs_<hostname>.txt`
EOT
}

TO: SBA-OP
------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
# Remove the masking/zoning
----------------------------
Execute these commands on the host

# define variables if they are not set yet
{
cat <<EOT
# Template: STORAGE REQUEST - Change masking
# Title: Removal of zoning and masking for <hostname>
Impacted host: <hostname>
HBA-PORTS Impacted devices:
`cat /sys/class/fc_host/host?/port_name`

Reason: Client is going to be decommissioned

Best regards
EOT
}

TO: SBA-OP
------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
Retrieve information for later
-------------------------------
Recover the ip address

Retrieve address for the service processor:

export ILO=`/home/admin/bin/getcmdb.sh cons | grep <hostname>-sc | awk '{print $1}' | cut -f 1 -d ";"` && echo $ILO

------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------


====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
!!!!!!!!!! Wait until the storage finishes the cleanup (retrieve luns if any and remove masking) !!!!!!!!!!
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================

====================================================================================================================================
# Shutdown the server
----------------------
shutdown -h now
 OR
poweroff

====================================================================================================================================
Remove the server from satellite
---------------------------------
If you have the necessary rights go to satellite page https://satellite-pk search for the server and the right site you will have a click button

Open satellite WebGUI
Goto Hosts
enter <hostname> in the search window 
Select the host
In the edit drop down menu select delete
confirm

 OR

satellite_delete_host <hostname>

====================================================================================================================================
Network: Remove IP and DNS entry for the server 
------------------------------------------------

Connect to http://resop/ip and fill in the form

- enter the hosts
- enter the CNAME

TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
CNAME=`grep -i CNAME ${TMP_FOLDER}/etc_hosts_<hostname>.txt | grep -v opsvc0000 | awk '{print $NF}'` && echo "# CNAME=$CNAME"

# Hosts IP @
printf "%-12s: " <hostname> && dig <hostname>.opoce.cec.eu.int +short

# Create the excel request file (template: OPS-RFC-DNS-delete.xltx)
generate_ip_delete_hostlist_records <hostname> $CNAME | tee ~claeyje/snet/data.txt

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET <hostname> $CNAME

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
- enter the CNAME if any

# send the request

OR

# Use a script to generate the Excel file contents
#----------------------------------------------------
{
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
CNAME=`grep -i CNAME ${TMP_FOLDER}/etc_hosts_<hostname>.txt | grep -v opsvc0000 | awk '{print $NF}'` && echo "# CNAME=$CNAME"

# view the IP @
for H in <hostname> bkp-<hostname> <hostname>-sc; do printf "%-12s: " $H && dig ${H}.opoce.cec.eu.int +short;done

HL="<hostname> <hostname>-sc $CNAME"

# Create the excel request file
generate_ip_delete_hostlist_records $HL | tee /snet/data.txt

# On Windows, create a new excel sheet based on the "OPS-RFC-DNS-RF2.3-delete.xltx" template
# run the DNS_delete_entry macro

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $HL 
}

====================================================================================================================================

Ticket:
====================================================================================================================================
Inform the CMDB manager about remove
-------------------------------------

TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>

{
cat << EOT
Dear all,

Please change the status of the nodes:

`cat ${TMP_FOLDER}/sysinfo_<hostname>.txt`

to

MODE: REMOVED/ARCHIVED.

Best regards
EOT
} | mailx -s "Change CMDB for <hostname> to archived" -r $email -c $email OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu


====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================

DCF-OP : Server can be unwired
-------------------------------

Create an SMT Ticket and assign it to DCF-OP for unwiring
----------------------------------------------------------

{
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
cat << EOT

# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Unwire <hostname>

Dear all,

Please unwire the following systems from the infrastructure:

`cat ${TMP_FOLDER}/sysinfo_<hostname>.txt`

will be removed from the rack

Best regards
EOT
}

====================================================================================================================================
Ticket:

====================================================================================================================================
====================================================================================================================================
!!!!! WAIT until the server has been unwired !!!!!
====================================================================================================================================
====================================================================================================================================

Create a second SMT ticket, assigned to DCF-OP for the physical remove
------------------------------------------------------------------------

{
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
cat << EOT
# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Remove <hostname> physically

Dear all,

please remove the following systems physically:

`cat ${TMP_FOLDER}/sysinfo_<hostname>.txt`

has order to be disconnected and can now remove from rack.

Best regards

EOT
}

====================================================================================================================================

Ticket:
====================================================================================================================================

====================================================================================================================================
