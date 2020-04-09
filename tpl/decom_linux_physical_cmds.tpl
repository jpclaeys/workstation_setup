decom linux physical server - <hostname>
-----------------------------------------

====================================================================================================================================
====================================================================================================================================
Open a session On the host
====================================================================================================================================

# Fetch info about the Hosts
------------------------------

fetch_decom_info_about_linux_host

------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
# If there is a freeze period before removing the server
---------------------------------------------------------
1. shutdown the server
-----------------------
date && shutdown -h now # OR date && poweroff
date && poweroff

# connect on the console and double-check that the server is powered off
# If the server is still powered on, force the power-off

2. Put the main ticket in "Planned" and schedule it after 30 days
------------------------------------------------------------------
User Additional Info:
----------------------
The server <hostname> has been shut down as requested.
Freeze period before deletion: 30 days

Check box "Planned by current group"
... After: set current date +30 days.

====================================================================================================================================
====================================================================================================================================
                                                  Wait until until the end of the freeze period
====================================================================================================================================
====================================================================================================================================

{
# Remove the luns if any
#------------------------
# rescan the SCSI bus
for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done

# Try removal by using the removelun_rhel script (Requires Switch.pm module for perl)
[ `find /usr/share/perl5 -type f -name Switch.pm | grep -c Switch.pm` -eq 0 ] && errmsg "Perl Switch.pm module is missing"
find /usr/share/perl5 -type f -name Switch.pm
for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort -k2 | awk '{print $1}'`; do echo "/home/admin/bin/removelun_rhel $LUN | bash";done
time for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort -k2 | awk '{print $1}'`; do /home/admin/bin/removelun_rhel $LUN | bash ;done
# Check: all LUNs are gone
multipath -ll; multipath -ll | egrep -c 'EMC|HITACHI'
}

# removelun_rhel doesn't work, do it manually
#---------------------------------------------
{
multipath -ll | grep 3600
DEVLIST=`multipath -ll | grep running | awk '{print $(NF-4)}' ` && echo $DEVLIST
DEVALIAS=`multipath -ll | grep EMC | awk '{print $1}' ` && echo $DEVALIAS
#for i in $DEVALIAS; do echo multipath -f /dev/mapper/${i}P1;done | bash   # for i in $DEVALIAS; do echo multipath -f /dev/mapper/$i;done | bash
for i in $DEVALIAS; do echo multipath -f /dev/mapper/$i;done | bash
for i in $DEVLIST; do echo "echo offline > /sys/block/$i/device/state"; echo "echo 1 >/sys/block/$i/device/delete" ;done | bash
multipath -ll
# Check: all LUNs are gone
multipath -ll; multipath -ll | egrep -c 'EMC|HITACHI' 
}

# Get local disks size
#-----------------------
fdisk -l | grep '^Disk /dev/' | grep -v mapper

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
====================================================================================================================================

====================================================================================================================================
# Create ticket for storage: retrieve storage
----------------------------------------------

wc -l $TMP_FOLDER/LUNs_<hostname>.txt
{
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
cat <<EOT
#SMT Template: STORAGE REQUEST - Retrieve unused storage
#SMT Title: Recover storage for <hostname>
Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): VMAX
Impacted hosts: <hostname>
Masking info (vm, datastore, zone,... name): <hostname>
LUN WWN and/or ID:
`cat $TMP_FOLDER/LUNs_<hostname>.txt | sort -k2`
EOT
}
 OR if the LUNs list is too big
{
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
LOGDIR=/home/claeyje/log/decom_linux_physical
F=LUNs_<hostname>.txt
\cp $TMP_FOLDER/$F ${LOGDIR} && chown claeyje:opunix ${LOGDIR}/$F
cat <<EOT
#SMT Template: STORAGE REQUEST - Retrieve unused storage
#SMT Title: Recover storage for <hostname>
#Attach document: ${LOGDIR}/$F
Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): VMAX
Impacted hosts: <hostname>
Masking info (vm, datastore, zone,... name): <hostname>
LUN WWN and/or ID: Cfr. attachment
EOT
}

TO: SBA-OP
------------------------------------------------------------------------------------------------------------------------------------
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
EOT
}

TO: SBA-OP
------------------------------------------------------------------------------------------------------------------------------------
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

s satellite-pk
satellite_delete_host <hostname>
satellite_host_list <hostname>

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

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

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
====================================================================================================================================
Poweroff the server
--------------------

Console( ILO 4)
Power Switch
Press and Hold

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
====================================================================================================================================
Reset the consoles to factory defaults
---------------------------------------

Resetting the IMM2 to the factory defaults
--------------------------------------------

Select the "IMM Management" tab
Select the "IMM Configuration" tab
Select the "Reset IMM to factory defaults" option
Confirm Reset to factory defaults

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
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
echo
# view the IP @
for H in <hostname> bkp-<hostname> <hostname>-sc; do printf "%-12s: " $H && dig ${H}.opoce.cec.eu.int +short | head -1 ;done
echo
HL="<hostname> <hostname>-sc $CNAME"

# Create the excel request file (template: OPS-RFC-DNS-delete.xltx)
DATAFILE="/home/claeyje/snet/data.txt"
generate_ip_delete_hostlist_records $HL | tee $DATAFILE && chown claeyje:opunix $DATAFILE
echo && ll $DATAFILE

# On Windows, create a new excel sheet based on the "OPS-RFC-DNS-RF2.3-delete.xltx" template
# run the DNS_delete_entry macro

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $HL 
}

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
Inform the CMDB manager about remove
-------------------------------------
{
echo "The server <hostname> has been decommissioned; it can be removed from the CMDB."
} | mailx -s "Update the CMDB: <hostname>" -r $email -c $email OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
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
DCF-OP : Server can be unwired
-------------------------------

Create an SMT Ticket and assign it to DCF-OP for unwiring
----------------------------------------------------------

{
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
cat << EOT

# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Unwire <hostname>

Please unwire the following systems from the infrastructure:
`cat ${TMP_FOLDER}/sysinfo_<hostname>.txt`

It will be removed from the rack
EOT
}

TO: DCF-OP
------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------
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

Please remove the following system physically:

`cat ${TMP_FOLDER}/sysinfo_<hostname>.txt`

It must be disconnected and can now be removed from the rack.
EOT
}
TO: DCF-OP
------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------
====================================================================================================================================
