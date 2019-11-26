How to retire a physical server
HOST_NAME=<hostname>
ssh $HOST_NAME
su - opsys_ux

exec bash
. ~claeyje/root_profile




1 Description

This procedure describe how to remove a server from operations
2 Input/Prerequisite

You need to have the password for the service processor (ILOM)

# Check that that the server is empty
zoneadm list -civ

# If primary domain, make sure that the secondary doamin is inactive

ldm list


Variables to define are as follows:

decom_server_set_vars <hostname>
[ ! -d $TMP_FOLDER ] && mkdir $TMP_FOLDER
cd $TMP_FOLDER

OR

export HOST_NAME=`uname -n`
export IP=`/home/admin/bin/getcmdb.sh host | grep $HOST_NAME | cut  -f 2 -d ";"`
export IP_LIST=
export TMP_FOLDER=${UNIXSYSTEMSTORE}/temp/${HOST_NAME}
 
export ILOM=`/home/admin/bin/getcmdb.sh cons | grep $HOST_NAME | awk '{ print $1}' | cut -f 1 -d ";"`
export SYSTEM=`/home/admin/bin/getcmdb.sh host | grep $HOST_NAME | cut  -f 7 -d ";" |  awk '{print $1}'`
export RELEASE=`/home/admin/bin/getcmdb.sh host | grep $HOST_NAME | cut  -f 7 -d ";" |  awk '{print $2 " " $3}'`
export OS="${SYSTEM} ${RELEASE}"
export SERNUMB_CHASSIS=`/home/admin/bin/getcmdb.sh serial | grep $HOST_NAME | cut  -f 9 -d ";"`
export LOCATION=`/home/admin/bin/getcmdb.sh host | grep $HOST_NAME | cut  -f 5 -d ";"`
export MODEL=`/home/admin/bin/getcmdb.sh host | grep $HOST_NAME | cut  -f 10 -d ";"`
who=`who am i | awk '{print $1}'`
email=`ldapsearchemail $who`

3 Operations
3.1 Step 1: Prepare
3.1.1 Description

Prepare the server and retrieve information for later
3.1.2 Instructions

[ ! -d $TMP_FOLDER ] && mkdir $TMP_FOLDER

decom_sysinfo_and_ip

OR

cat << EOT > $TMP_FOLDER/sysinfo_${HOST_NAME}.txt
 `echo "HOST_NAME: " $HOST_NAME`
 `echo "IP: "    $IP`
 `echo "MODEL: " $MODEL`
 `echo "OS : "   $OS`
 `echo "LOCATION : " $LOCATION`
 `echo "SERIAL# : " $SERNUMB_CHASSIS`
EOT
cat $TMP_FOLDER/sysinfo_${HOST_NAME}.txt

# Gather IP info

getent hosts  | grep -v `clnode list | grep -v $HOST_NAME` | grep -v localhost | grep -v `cat /etc/hosts  | grep -i quorum | awk '{print $2}' ` > ${TMP_FOLDER}/network_ip.txt
echo "`nslookup bkp-${HOST_NAME} |  grep -n Address | grep 6: |awk '{print $2}' `   bkp-${HOST_NAME}  " >> ${TMP_FOLDER}/network_ip.txt
cat ${TMP_FOLDER}/network_ip.txt

3.2 Step 2: Inform the other divisions
3.2.1 Description

Inform the necessary divisions
Request removal
3.2.1.1 Request from the CMDB management to change status to stop

connect to the server via ssh and enter the following codes

{
cat <<EOT
Dear all,
 
Can you please change the status of the node 
 
$HOST_NAME
$IP
 
in the cmbd to 
 
MODE: stop.
 
 
Best regards
 
 
EOT
} | mailx -s "Change CMDB for ${HOST_NAME} to stop" -r $who -c $who OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu

3.2.1.2 Request to SBA to remove backup client

Create SMT Ticket to SBA-OP with following text using the template : Delete client

As an alternative, you can send an email to BACKUP-STORAGE team:

{
cat <<EOT
 
Removal of backup client `cat ${TMP_FOLDER}/network_ip.txt | grep bkp | awk '{print $2}'` 
 
Client name: `cat ${TMP_FOLDER}/network_ip.txt | grep bkp | awk '{print $2}'`
IP Address: `cat ${TMP_FOLDER}/network_ip.txt | grep bkp | awk '{print $1}'`
OS: $OS
Reason: Client is going to be retrieved
 
Best regards
EOT
}| mailx -s "Removal of backup client for ${HOST_NAME}" -r $who -c $who,OPDL-A4-STORAGE-BACKUP@publications.europa.eu

3.2.1.3 System remove: Oracle Grid

{
cat <<EOT
Dear all,
 
please remove the following system from the Oracle GRID/Monitoring if required:
 
 
CLient name: $HOST_NAME
IP Address:  $IP
REASON: System will be removed
 
Thank you in advance
 
EOT
} | mailx -s "Remove ${HOST_NAME} from the monitoring" -r $who -c $who OP-INFRA-DB@publications.europa.eu

3.2.1.4 Remove the server from puppet puppet / cfengine

If you have the necessary rights go to forman page https://foreman search for the server and the right site you will have a click button

As an alternative, you can send an email to OPDL INFRA SYSTEMS team:

{
cat <<EOT
Dear all,
 
please remove the client for Puppet and CFengine if required from the following system
 
 
CLient name: $HOST_NAME
IP Address: $IP
REASON: System will be removed
 
Thx you in advance
 
EOT
} | mailx -s "Remove Cfengine/Puppetclient from ${HOST_NAME} " -r $who -c $who,OPDL-INFRA-SYSTEMS@publications.europa.eu

3.2.1.5 Request to the storage team to remove zoning / masking

Retrieve WWN

{
for wwn in `fcinfo hba-port | grep HBA | awk '{print $4}'`
do
   echo $wwn
   fcinfo remote-port -p $wwn | grep Remote | awk '{print $4}'
done
 
} >${TMP_FOLDER}/${HOST_NAME}_wwn_to_recover.txt
 
cat ${TMP_FOLDER}/${HOST_NAME}_wwn_to_recover.txt

Open a SMT ticket with SBA-OP and sent the following information:

As an alternative, you can send an email to BACKUP-STORAGE team:

{
cat <<EOT
 
Removal of zoning and masking for $HOST_NAME
 
Impacted host(s):$HOST_NAME
IP Address: $IP
OS: $OS
MODEL: $MODEL
HBA-PORTS Impacted devices:
`cat ${TMP_FOLDER}/${HOST_NAME}_wwn_to_recover.txt | sort -u`
 
 
Reason: Client is going to be retrieved
 
Best regards
EOT
} | mailx -s "Removal of zoning and masking for ${HOST_NAME}" -r $who -c $who,OPDL-A4-STORAGE-BACKUP@publications.europa.eu

3.2.1.6 Inform the systems team

{
cat <<EOT
Dear all,
 
due to the phase out, the server $HOST_NAME will be manipulated.
 
Please ignore message and alarms for this system.
 
 
Thank you for your comprehension and best regards
 
 
EOT
} | mailx -s "Maintenance on ${HOST_NAME}" -r $who -c $who,OPDL-INFRA-SYSTEMS@publications.europa.eu

3.2.1.7 Change the boot variables

hostname; eeprom | egrep 'auto-boot\?\=|diag-switch'

eeprom auto-boot?=false
eeprom diag-switch?=false

eeprom | egrep 'auto-boot\?\=|diag-switch'

3.2.1.8 Remove the quorum disks 

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

Once you received the green light from the zoning team unconfigure every hba:

For example if the hba have the physical addresses c2 and c3, then execute

cfgadm  -c unconfigure c2 c3

3.3.1 INT Prod: Remove entry wood/portal

to be defined
3.3.2 Retrieve information for later

Recover the ip address

Retrieve address for the service processor:

export ILOM=`/home/admin/bin/getcmdb.sh cons | grep $HOST_NAME | awk '{ print $1}' | cut -f 1 -d ";"`
echo $ILOM ''

3.2.2.0 In case of a secondary domain, connect to the primary domain

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

ssh root@$ILOM
-> start /SP/console

3.3.2.2 In case of XSCF (M-Series)

ssh xscfadm@$ILOM
XSCF> showdomainstatus -a
XSCF> console -d <domain> -y

3.3.2.3 Either shutdown the cluster or evacuate the current node

/usr/cluster/bin/cluster shutdown -g0 -y

OR

/usr/cluster/bin/clnode evacuate `uname 'n `
init 0

3.3.3 Boot in single user mode on net

boot net -s

If you are prompted for a user name for system maintenance, type “root” and password: “solaris”

In case the installation server is not found check the alias for net, the installation server is aiserver-pz

Chose shell in the installation menu
3.3.4 Wipe the disks

 
for disk in `luxadm probe | grep Logical | cut -f 2 -d ":"`;do  luxadm -e offline $disk; done
 
luxadm probe
 
for disk in `echo | format | egrep -iv 'emc|pci|configured|iscsi|quorum|disk' | awk '{print $2}' | xargs -L1`
do 
    (echo "`date`: Starting dd on $disk" && time dd if=/dev/urandom of=/dev/rdsk/${disk}s2 obs=16777216 && fmthard -s /dev/zero /dev/rdsk/${disk}s2 && echo "`date`: Finished dd on $disk") &
done

Depending on the size of the disks, this can take time

On M5K-Series, wiping 300 GB disks takes about 8 hours when using 16 Mb output block size.

Please be aware that the shell needs to be maintained. If not the processes breaks.

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

3.4.2 Request to remove monitoring client

Redefine variables

. ~/bin/decom_functions.sh
decom_set_finish_vars <hostname>

 OR 

export HOST_NAME=
export TMP_FOLDER=${UNIXSYSTEMSTORE}/temp/${HOST_NAME}
who=`who am i | awk '{print $1}'`
email=`ldapsearchemail $who`

{
cat <<EOT
Dear all,
 
please remove the following system from the monitoring:
 
 
CLient name: `cat ${TMP_FOLDER}/network_ip.txt | grep -v bkp | awk '{print $2}'`
IP Address: `cat ${TMP_FOLDER}/network_ip.txt | grep -v bkp | awk '{print $1}'`
REASON: System will be removed
 
Thx you in advance
 
EOT
} | mailx -s "Remove ${HOST_NAME} from the monitoring" -r $who -c $who,OPDL-INFRA-INT-PROD@publications.europa.eu,op-helpdesk@publications.europa.eu OP-IT-PRODUCTION.europa.eu

3.4.3 Network: Remove IP and DNS entry

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


3.4.4 Inform the team that the server will be removed

. ~/bin/decom_functions.sh
decom_set_finish_vars <hostname>

 
{
cat << EOT
 
Dear all,
 
Please be informed that the node
 
`cat $TMP_FOLDER/sysinfo_${HOST_NAME}.txt`
 
has been deconfigured and powered off. 
 
 
It will be removed from the rack and is no further available.
 
 
 
Best regards
 
 
EOT
} | mailx -s "${HOST_NAME} has been deconfigured and powered off" -r $who -c $who,OPDL-INFRA-SYSTEMS@publications.europa.eu

3.4.5 TEL-NET-OPOCE : Server can be unwired

Create an SMT Ticket and assign it to TEL-NET-OPOCE for unwiring

Template: OP_INFRA_SYSTEM decommissionnement

 
{
cat << EOT
 
Unwire ${HOST_NAME}
 
 
Dear all,
 
please unwire the following system from the infrastructure:
 
`cat $TMP_FOLDER/sysinfo_*.txt`
 
 
will be removed from the rack
 
 
Best regards
 
 
EOT
}

Create a second SMT ticket, assigned to DCF-OP for the physical remove:


{
cat << EOT

Remove ${HOST_NAME} physically 

Dear all,

please remove the following system physically:

`cat $TMP_FOLDER/sysinfo_*.txt`

has order to be disconnected and can now remove from rack.


Best regards


EOT
}   

3.4.6 Inform the CMDB manager about remove

{
cat << EOT
Dear all,
 
we would like to query you to change the status of the node 
 
`cat $TMP_FOLDER/sysinfo_*.txt`
 
to 
 
MODE: REMOVED/ARCHIVED. 
 
 
Best regards
 
 
EOT
} | mailx -s "Change CMDB for ${HOST_NAME} to archived" -r $who -c $who OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu

3.4.7 Ask to update the schema

 
{
cat << EOT
Dear all,
 
we would query you to adapt the schema regarding 
 
`cat $TMP_FOLDER/sysinfo_*.txt`
 
 
which has been removed
 
 
 
Best regards
 
 
EOT
} | mailx -s "Update schema due to remove of ${HOST_NAME} " -r $who -c $who,OPDL-INFRA-SYSTEMS@publications.europa.eu


3.4.8 Remove monitoring of the console

ILOM=

{
cat <<EOT
Dear all,

please remove the following system from the monitoring:

CLient name: `host $ILOM| awk '{print $1}'`
IP Address: `host $ILOM| awk '{print $NF}'`
REASON: System will be removed

Thx you in advance

EOT
} | mailx -s "Remove $ILOM from the monitoring" -r $who -c $who,OPDL-INFRA-INT-PROD@publications.europa.eu,op-helpdesk@publications.europa.eu OP-IT-PRODUCTION.europa.eu


3.4.9 Reset the Service Processor to the factory settings

Connect to the web gui (Firefox)
Navigation
ILOM Administration
Configuration Management
Reset Defaults
Factory

The configuration change will be applied the next time the Service Processor is reset

on the console
-> reset /SP

------------------------------------------------------
Output/Validation

The server is inactive and can physically removed

