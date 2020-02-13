decom multiple linux physical hosts
----------------------------------------------------------------
====================================================================================================================================

====================================================================================================================================
unalias cat
HL=`echo "

" | sort | xargs` && echo $HL && wc -w <<< $HL

ex.
HL="anakin chewbacca deathstar draco ewok han hydra jabba lando leia luke obiwan padawan palpatine r2d2 sidious vader yoda bootes fornax"
====================================================================================================================================

goto to opvmwstsx11

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
OP - REMOVE MONITORING: $HL

# Description: 

Application Name IS : 
Servers list: $HL
Action: Stop monitoring
EOT
}

TO:  IT-PRODUCTION-OP
------------------------------------------------------------------------------------------------------------------------------------
Ticket: 
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
# Open a ticket to delete the backup clients
---------------------------------------------

Template: OP - REMOVE BACKUP
Incident type: REQUEST FOR SERVICE
Configuration item: SERVER
System: HARDWARE AND OPERATING SYSTEMS
Component: SERVERS

{
CLIENTS=`for H in $HL; do echo "bkp-${H}";done|xargs` && echo $CLIENTS && wc -w <<< $CLIENTS

cat <<EOT
# Title: 
OP - REMOVE BACKUP: $CLIENTS

# Template: 
BACKUP REQUEST - Delete clients

# Description:
Client names: $CLIENTS
OS: Linux
Reason: servers removed
EOT
}

To: SBA-OP

====================================================================================================================================
Ticket: 
====================================================================================================================================

====================================================================================================================================
Open a session On all servers 
====================================================================================================================================

# Fetch info about the Hosts
------------------------------
. ~claeyje/bin/root_profile
HOST=`uname -n | cut -d'.' -f1`
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/${HOST}
[ ! -d "$TMP_FOLDER" ] && mkdir $TMP_FOLDER && cd $TMP_FOLDER

# Create the sysinfo file (from cmdb)
save_decom_linux_vars

# Save HBS WWN's
cat /sys/class/fc_host/host?/port_name | tee $TMP_FOLDER/hba_wwns_${HOST}.txt

# Save /etc/hosts
cat /etc/hosts | tee $TMP_FOLDER/etc_hosts_$HOST

# Save IP info
ip a | tee $TMP_FOLDER/ip_config_${HOST}.txt

# Get luns
------------
# rescan the SCSI bus
for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done
# Get the luns
multipath -ll | egrep 'EMC|HITACHI'  | sort | tee $TMP_FOLDER/LUNs_${HOST}.txt

# List $TMP_FOLDER content
ls -lh $TMP_FOLDER

====================================================================================================================================
# Create ticket for storage: retrieve storage
----------------------------------------------

# define variables if they are not set yet
-------------------------------------------
definemypasswd
echo $HL && wc -c <<< $HL
ALLLUNS="all_lun_`date "+%Y%m%d"`.txt"
for H in $HL; do msggreen $H && sr $H multipath -ll | grep EMC| grep -v "^-";done | tee $ALLLUNS

cat <<EOT
# SMT Template: 
STORAGE REQUEST - Retrieve unused storage
# SMT Title: 
Recover storage for: $HL
# Description:
Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): VMAX
Impacted hosts: $HL

Masking info (vm, datastore, zone,... name): $HL
LUN WWN and/or ID:
`cat $ALLLUNS`
EOT

To: SBA-OP

====================================================================================================================================
Ticket:
====================================================================================================================================
# Remove the masking/zoning
----------------------------

# define variables if they are not set yet
-------------------------------------------
echo $HL && wc -c <<< $HL
HBAINFO="all_hosts_hba_info_`date "+%Y%m%d"`.txt"
CMD='echo "Impacted host: `hostname`" && echo -n "IP Address: " && dig `hostname`.opoce.cec.eu.int +short && echo -n "OS: " && cat /etc/system-release && echo "HBA-PORTS Impacted devices:" && cat /sys/class/fc_host/host?/port_name && echo' && echo $CMD
for H in $HL; do s $H "($CMD)";done | tee $HBAINFO

# Insert the ouput of the above command to the following text:
---------------------------------------------------------------

cat <<EOT
# Template: 
STORAGE REQUEST - Change masking
# Title: 
Removal of zoning and masking for: $HL
# Description:

`cat $HBAINFO`

Reason: Clients are going to be decommissioned
EOT

To SBA-OP

====================================================================================================================================
Ticket: 
====================================================================================================================================

# On all servers remove the luns
----------------------------------

check-multipath.pl
for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort | awk '{print $1}'`; do echo "/home/admin/bin/removelun_rhel $LUN | bash";done
for LUN in `multipath -ll | egrep 'EMC|HITACHI' | sort | awk '{print $1}'`; do /home/admin/bin/removelun_rhel $LUN | bash ;done

# Check: all LUNs are gone
multipath -ll | egrep -c 'EMC|HITACHI'
check-multipath.pl

====================================================================================================================================


====================================================================================================================================
3.2.2 Retrieve information for later
Recover the ip address

Retrieve address for the service processor:

for H in $HL; do /home/admin/bin/getcmdb.sh cons | grep $H| awk '{ print $1}' | cut -f 1 -d ";" | xargs;done

====================================================================================================================================




====================================================================================================================================


====================================================================================================================================
====================================================================================================================================
!!!!!!!!!! Wait until the storage finishes the cleanup (retrieve luns if any and remove masking) !!!!!!!!!!
====================================================================================================================================
====================================================================================================================================


====================================================================================================================================

# Shutdown all servers
-----------------------
shutdown -h now
 OR
poweroff

====================================================================================================================================
3 Remove the servers from satellite
-------------------------------------
If you have the necessary rights go to satellite page https://satellite-pk search for the server and the right site you will have a click button

Opsatellite WebGUI
Goto Hosts
search the hosts
Select Action drop down menu: delete
Submit

 OR

echo $HL && wc -c <<< $HL
satellite_delete_host $HL
------------------------------------------------------------------------------------------------------------------------------------
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

If the Web gui doesn't provide the reset option (ex. on Blades)
-----------------------------------------------------------------

Navigating to the iLO 2 RBSU and selecting Factory Defaults
reboot the server, press F8 to enter to iLO 2 RBSU and restore the factory defaults from there.
RBSU: ROM-Based Setup Utility

Power ON
During POST, hit [F8]

File
Set Defaults
Confirmation / Set to factory defaults ? / [F10]=OK

File
Exit

====================================================================================================================================
3.3.2 Network: Remove IP and DNS entry for the server, the bkp and the consoles
---------------------------------------------------------------------------------

Connect to http://resop/ip and fill in the form

- enter the hosts
- enter the bkp-hosts
- enter the opsrvxxx
- enter the consoles

{
echo $HL
# Hosts IP @
for H in $HL; do printf "%-12s: " $H && dig ${H}.opoce.cec.eu.int +short;done
# backup IP @
for H in $HL; do printf "%-12s: " bkp-${H} && dig bkp-${H}.opoce.cec.eu.int +short;done
# opsrv
FILTER=`echo $HL| sed 's/ /|/g'` && echo "Hosts filter:= $FILTER"
OPSRV=`cmdb opsrv | egrep "\;($FILTER)" | awk -F";" '{print $1}'| xargs` && echo "OPSRV:= $OPSRV"
# Consoles
CONSL=`for H in $HL; do echo ${H}-sc;done|xargs` && echo $CONSL
for H in $CONSL; do printf "%-15s: " ${H} && dig ${H}.opoce.cec.eu.int +short | xargs;done
# ALLHL="$HL $OPSRV $CONSL"
ALLHL="$HL $OPSRV"
}

# validate the opsrv values
for H in $OPSRV; do echo -n "$H " && s $H uname -n;done

# Create the excel request file
generate_ip_delete_hostlist_records $ALLHL | tee ~claeyje/snet/data.txt

# On Windows, create a new excel sheet based on the "OPS-RFC-DNS-RF2.3-delete.xltx" template
run DNS_delete_entry macro

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $ALLHL


====================================================================================================================================

Ticket:
====================================================================================================================================

====================================================================================================================================
3.3.5 Inform the CMDB manager about remove
-------------------------------------------

# goto opvmwstsx11
# Define the hosts list

HL=

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
