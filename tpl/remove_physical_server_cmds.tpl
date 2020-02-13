How to decommission a physical server
--------------------------------------
HOST_NAME=<hostname>
ssh <hostname>
su - opsys_ux

exec bash
. ~claeyje/root_profile

1 Description
--------------

This procedure describes how to remove a server

2 Input/Prerequisite
---------------------

You need to have the password for the service processor (ILOM)

# Check that that the server is empty
zoneadm list -civ

# If primary domain, make sure that the secondary doamin is inactive
ldm list

# define the env variables 

decom_server_set_vars <hostname>
[ ! -d $TMP_FOLDER ] && mkdir $TMP_FOLDER
cd $TMP_FOLDER

OR

export IP=`/home/admin/bin/getcmdb.sh host | grep <hostname> | cut  -f 2 -d ";"`
export IP_LIST=
export TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/<hostname>
 
export ILOM=`/home/admin/bin/getcmdb.sh cons | grep <hostname> | awk '{ print $1}' | cut -f 1 -d ";"`
export SYSTEM=`/home/admin/bin/getcmdb.sh host | grep <hostname> | cut  -f 7 -d ";" |  awk '{print $1}'`
export RELEASE=`/home/admin/bin/getcmdb.sh host | grep <hostname> | cut  -f 7 -d ";" |  awk '{print $2 " " $3}'`
export OS="${SYSTEM} ${RELEASE}"
export SERNUMB_CHASSIS=`/home/admin/bin/getcmdb.sh serial | grep <hostname> | cut  -f 9 -d ";"`
export LOCATION=`/home/admin/bin/getcmdb.sh host | grep <hostname> | cut  -f 5 -d ";"`
export MODEL=`/home/admin/bin/getcmdb.sh host | grep <hostname> | cut  -f 10 -d ";"`
who=`who am i | awk '{print $1}'`
email=`ldapsearchemail $who`

3 Operations
-------------

3.1 Step 1: Prepare
3.1.1 Description
------------------

Prepare the server and retrieve information for later

3.1.2 Instructions
-------------------

[ ! -d $TMP_FOLDER ] && mkdir $TMP_FOLDER

decom_sysinfo_and_ip

OR

cat << EOT > $TMP_FOLDER/sysinfo_<hostname>.txt
 `echo "HOST_NAME: " <hostname>`
 `echo "IP: "    $IP`
 `echo "MODEL: " $MODEL`
 `echo "OS : "   $OS`
 `echo "LOCATION : " $LOCATION`
 `echo "SERIAL# : " $SERNUMB_CHASSIS`
EOT
cat $TMP_FOLDER/sysinfo_<hostname>.txt

# Gather IP info

getent hosts  | grep -v `clnode list | grep -v <hostname>` | grep -v localhost | grep -v `cat /etc/hosts  | grep -i quorum | awk '{print $2}' ` > ${TMP_FOLDER}/network_ip.txt
echo "`nslookup bkp-<hostname> |  grep -n Address | grep 6: |awk '{print $2}' `   bkp-<hostname>  " >> ${TMP_FOLDER}/network_ip.txt
cat ${TMP_FOLDER}/network_ip.txt

3.2 Step 2: Inform the other divisions
3.2.1 Description

Inform the necessary divisions
Request removal

------------------------------------------------------------------------------------------------------------------------------------
3.2.1.1 Request from the CMDB management to change status to stop
------------------------------------------------------------------

connect to the server via ssh and enter the following codes

{
cat <<EOT
 
Please change the status of the node 
 
<hostname>
$IP
 
in the cmbd to 
 
MODE: stop.
EOT
} | mailx -s "Change CMDB for <hostname> to stop" -r $who -c $who OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu

------------------------------------------------------------------------------------------------------------------------------------
3.2.1.2 Open a ticket to delete the backup client
---------------------------------------------------

{
cat <<EOT
#SMT Template: BACKUP REQUEST - Delete client
#SMT Title: Remove backup client for `cat ${TMP_FOLDER}/network_ip.txt | grep bkp | awk '{print $2}'` 
 
Client name: `cat ${TMP_FOLDER}/network_ip.txt | grep bkp | awk '{print $2}'`
IP Address:  `cat ${TMP_FOLDER}/network_ip.txt | grep bkp | awk '{print $1}'`
OS: $OS
Reason: server removed
EOT
}

TO: SBA-OP
------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------

3.2.1.3 System remove: Oracle Grid
-----------------------------------

{
cat <<EOT
Please remove the following system from the Oracle GRID/Monitoring if required:
 
CLient name: <hostname>
IP Address:  $IP
REASON: System will be removed
 
Thank you in advance
EOT
} | mailx -s "Remove <hostname> from the monitoring" -r $who -c $who OP-INFRA-DB@publications.europa.eu

------------------------------------------------------------------------------------------------------------------------------------
3.2.1.4 Remove the server from puppet puppet / cfengine
--------------------------------------------------------
Goto the foreman page https://foreman search for the server and the right site you will have a click button


------------------------------------------------------------------------------------------------------------------------------------
3.2.1.5 Request to the storage team to remove zoning / masking
----------------------------------------------------------------

Retrieve the WWN's

{
for wwn in `fcinfo hba-port | grep HBA | awk '{print $4}'`
do
   echo $wwn
   fcinfo remote-port -p $wwn | grep Remote | awk '{print $4}'
done
 
} >${TMP_FOLDER}/<hostname>_wwn_to_recover.txt
 
cat ${TMP_FOLDER}/<hostname>_wwn_to_recover.txt

Open a SMT ticket with SBA-OP and sent the following information:
------------------------------------------------------------------

{
cat <<EOT
# Template: STORAGE REQUEST - Change masking
# Title: Removal of zoning and masking for <hostname>
 
Impacted host(s):<hostname>
IP Address: $IP
OS: $OS
MODEL: $MODEL
HBA-PORTS Impacted devices:
`cat ${TMP_FOLDER}/<hostname>_wwn_to_recover.txt | sort -u`
 
Reason: Client is going to be decommissioned
EOT
}

TO:  SBA-OP
------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------

3.2.1.6 Inform the systems team
---------------------------------

{
cat <<EOT

Please ignore any alert for <hostname>, which is undergoining a phase out.
 
EOT
} | mailx -s "Maintenance on <hostname>" -r $who -c $who,OPDL-INFRA-SYSTEMS@publications.europa.eu

3.2.1.7 Change the boot variables
----------------------------------

hostname; eeprom | egrep 'auto-boot\?\=|diag-switch'

eeprom auto-boot?=false
eeprom diag-switch?=false

eeprom | egrep 'auto-boot\?\=|diag-switch'

3.2.1.8 Remove the quorum disks 
---------------------------------

# [Place the cluster in install mode:]
cluster set -p installmode=enabled

clq list -v | awk '/shared_disk/ {print $1}'
clq remove <did>
#[Verify that the quorum device has been removed:]
clquorum list -v


==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
                         Wait until the storage team has removed the zoning/masking
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================

3.3 Step 3 Prepare the reboot
------------------------------

Once you received the green light from the zoning team unconfigure every hba:

For example if the hba have the physical addresses c2 and c3, then execute

cfgadm  -c unconfigure c2 c3

3.3.2 Retrieve information for later
-------------------------------------

Recover the ip address

Retrieve address for the service processor:

export ILOM=`/home/admin/bin/getcmdb.sh cons | grep <hostname> | awk '{ print $1}' | cut -f 1 -d ";"`
echo $ILOM ''

3.2.2.0 In case of a secondary domain, connect to the primary domain
----------------------------------------------------------------------

ssh <primary domain>
su - opsys_ux

telnet localhost 5000
init 0
^]
quit

ldm list
ldm stop secondary && ldm list
ldm unbind secondary && ldm list

Connect to the serial console
3.3.2.1 In case of ILOM (T-Series)
-----------------------------------

ssh root@$ILOM
-> start /SP/console

3.3.2.2 In case of XSCF (M-Series)
-----------------------------------

ssh xscfadm@$ILOM
XSCF> showdomainstatus -a
XSCF> console -d <domain> -y

3.3.2.3 Either shutdown the cluster or evacuate the current node
-----------------------------------------------------------------

/usr/cluster/bin/cluster shutdown -g0 -y

OR

/usr/cluster/bin/clnode evacuate `uname 'n `
init 0

3.3.3 Boot in single user mode on net
--------------------------------------

boot net -s

If you are prompted for a user name for system maintenance, type “root” and password: “solaris”

In case the installation server is not found check the alias for net, the installation server is aiserver-pz

Chose "shell" in the installation menu

3.3.4 Wipe the disks
---------------------
 
for disk in `luxadm probe | grep Logical | cut -f 2 -d ":"`;do  luxadm -e offline $disk; done
 
luxadm probe
 
for disk in `echo | format | egrep -iv 'emc|pci|configured|iscsi|quorum|disk' | awk '{print $2}' | xargs -L1`
do 
    (echo "`date`: Starting dd on $disk" && time dd if=/dev/urandom of=/dev/rdsk/${disk}s2 obs=16777216 && fmthard -s /dev/zero /dev/rdsk/${disk}s2 && echo "`date`: Finished dd on $disk") &
done

Depending on the size of the disks, this can take time

On M5K-Series, wiping 300 GB disks takes about 8 hours when using 16 Mb output block size.

Please be aware that the shell needs to be maintained, otherwise the processes breaks.

In order to keep the shell online, use something like

vmstat 240 99999999

to make a keepalive (top is not available in the boot net)
3.4 Step 4 Power off the system
3.4.1 Power off the system
3.4.1.1 In case of XSCF (M-Series)

ssh xscfadm@${ILOM}
XSCF> showdomainstatus -d <domain>
XSCF> poweroff -d <domain>
XSCF> showdomainstatus -d <domain>
XSCF> showlogs power

To help the infrastructure staff, activate the locator led

XSCF> setlocator blink
XSCF> showlocator

3.4.1.2 In case of ILOM (T-Series)

ssh root@${ILOM}
-> stop /SYS
-> show -d properties /SYS

-> show /SYS power_state

To help the infrastructure staff, activate the locator led

-> set /SYS/LOCATE value=Fast_Blink
-> show /SYS/LOCATE
-> show /SYS/LOCATE value

====================================================================================================================================
3.4.2 Open ticket to remove the monitoring:
---------------------------------------------

{
cat <<EOT
# Title:
REMOVE MONITORING: <hostname> & <hostname>-sc
 
CLient name: <hostname> & <hostname>-sc
Action: Stop monitoring
Reason: Server removed
EOT
}

TO:  IT-PRODUCTION-OP
------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------

3.4.3 Network: Remove IP and DNS entry
---------------------------------------

cat $TMP_FOLDER/network_ip.txt

Connect to http://resop/ip and fill in the form


==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================

# If this is a secondary domain, wait until the primary domain has been deconfigured

==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================
==========================================================================================================================

3.4.5 Server can be unwired
----------------------------

Create an SMT Ticket and assign it to DCF-OP for unwiring
 
{
cat << EOT
# Template: OP_INFRA_SYSTEM decommissionnement
# Title: Unwire  <hostname>
 
Please unwire the following system from the infrastructure:
 
`cat $TMP_FOLDER/sysinfo_*.txt`
 
will be removed from the rack
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

`cat $TMP_FOLDER/sysinfo_*.txt`

must be disconnected and can now be removed from the rack.
EOT
}   

TO: DCF-OP
------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------
====================================================================================================================================

3.4.6 Inform the CMDB manager about remove

{
cat << EOT
 
Please change the status of the node 
 
`cat $TMP_FOLDER/sysinfo_*.txt`
 
to 
 
MODE: REMOVED/ARCHIVED. 
EOT
} | mailx -s "Change CMDB for <hostname> to archived" -r $who -c $who OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu


====================================================================================================================================
3.4.9 Reset the Service Processor to the factory settings
----------------------------------------------------------

Connect to the web gui (Firefox)
Navigation
ILOM Administration
Configuration Management
Reset Defaults
Factory

The configuration change will be applied the next time the Service Processor is reset

on the console
-> reset /SP

====================================================================================================================================

