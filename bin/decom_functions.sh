# decom functions
function define_email ()
{
who=`who am i | awk '{print $1}'`
email=`ldapsearchemail $who`
}
function decom_server_set_vars () 
{
define_root_path
export HOST_NAME=${1:-`uname -n`} 
export IP=`cmdb host | grep $HOST_NAME | cut  -f 2 -d ";"`
export IP_LIST=
export TMP_FOLDER=${UNIXSYSTEMSTORE}/temp/${HOST_NAME}
export ILOM=`cmdb cons | grep $HOST_NAME | awk '{ print $1}' | cut -f 1 -d ";"`
export SYSTEM=`cmdb host | grep $HOST_NAME | cut  -f 7 -d ";" |  awk '{print $1}'`
export RELEASE=`cmdb host | grep $HOST_NAME | cut  -f 7 -d ";" |  awk '{print $2 " " $3}'`
export OS="${SYSTEM} ${RELEASE}"
export SERIAL=`cmdb serial | grep $HOST_NAME | cut  -f 9 -d ";"`
export LOCATION=`cmdb host | grep $HOST_NAME | cut  -f 5 -d ";"`
export MODEL=`cmdb host | grep $HOST_NAME | cut  -f 10 -d ";"`
define_email
echo "
HOST_NAME   $HOST_NAME
IP          $IP
IP_LIST     $IP_LIST
TMP_FOLDER  $TMP_FOLDER
ILOM        $ILOM
SYSTEM      $SYSTEM
RELEASE	    $RELEASE
OS          $OS
LOCATION    $LOCATION
SERIAL#     $SERIAL
MODEL       $MODEL
email       $email
who         $who
"
}

function decom_zone_set_vars () 
{
[ $# -eq 0 ] && echo "PLease provice a zone name" && return 1
define_root_path
export zone_name=$1
export tmp_folder=${UNIXSYSTEMSTORE}/temp/${zone_name}
[ ! -d $tmp_folder ] && mkdir $tmp_folder
define_email
echo "
zone_name   $zone_name
tmp_folder  $tmp_folder
email       $email
who         $who
"
}

function decom_set_finish_vars ()
{
define_root_path
export HOST_NAME=${1:-`uname -n`}
export TMP_FOLDER=${UNIXSYSTEMSTORE}/temp/${HOST_NAME}
define_email
echo "
HOST_NAME   $HOST_NAME
TMP_FOLDER  $TMP_FOLDER
email       $email
who         $who
"
}

function decom_sysinfo_and_ip () {
[ `whoami` != "root" ] && echo "Need to be root" && return 1
export HOST_NAME=${1:-`uname -n`} 
export TMP_FOLDER=${UNIXSYSTEMSTORE}/temp/${HOST_NAME}
[ ! -d $TMP_FOLDER ] && mkdir $TMP_FOLDER

cat << EOT > $TMP_FOLDER/sysinfo_${HOST_NAME}.txt
 `echo "HOST_NAME: " $HOST_NAME`
 `echo "IP: "    $IP`
 `echo "MODEL: " $MODEL`
 `echo "OS : "   $OS`
 `echo "LOCATION : " $LOCATION`
 `echo "SERIAL# : " $SERIAL`
EOT
msg sysinfo_${HOST_NAME}
cat $TMP_FOLDER/sysinfo_${HOST_NAME}.txt
      
# Gather IP info

getent hosts  | grep -v `clnode list | grep -v $HOST_NAME` | grep -v localhost | grep -v `cat /etc/hosts  | grep -i quorum | awk '{print $2}' ` > ${TMP_FOLDER}/network_ip.txt
echo "`nslookup bkp-${HOST_NAME} |  grep -n Address | grep 6: |awk '{print $2}' `   bkp-${HOST_NAME}  " >> ${TMP_FOLDER}/network_ip.txt

msg Network_ip
cat ${TMP_FOLDER}/network_ip.txt
}

function get_asm_disk_ids ()
{
[ $# -eq 0 ] && echo "Please provide zone name " && return 1
[ `zoneadm list -c | grep -c $1` -eq 0 ] && echo "zone $1 is unknown" && return 1
DIDLIST=`zonecfg  -z $1 info device | awk -F"/" '/match/ {print $NF}'| sed 's/s.$//'| xargs` # && echo $DIDLIST
if [ ! -z "$DIDLIST" ]; then
  echo "\nASM disks for $1\n"
  # for DID in $DIDLIST; do cldev show -v $DID | grep -iv ascii | awk -F":" '/Disk ID/ {print $NF}'|xargs|sort;done
  cldev show -v $DIDLIST | grep -iv ascii | awk -F":" '/Disk ID/ {print $NF}' | sed 's/ //g' | sort
fi
}

function get_asm_lun_hex ()
{
[ $# -eq 0 ] && echo "Please provide zone name " && return 1
[ `zoneadm list -c | grep -c $1` -eq 0 ] && echo "zone $1 is unknown" && return 1
DIDLIST=`zonecfg  -z $1 info device | awk -F"/" '/match/ {print $NF}'| sed 's/s.$//'| xargs` # && echo $DIDLIST
#echo "\nASM luns hex for $1\n"
for DID in $DIDLIST; do awk '/ '$DID' / {print $9}'  storage_info_`uname -n`.txt | head -1;done
}

function get_asm_disks_size ()
{
[ $# -eq 0 ] && echo "Please provide zone name " && return 1
for DISK in `get_asm_disk_ids $1| grep ^6`; do luxadm disp /dev/rdsk/*${DISK}d0s2 | grep Unformat;done| awk '{sum += $3} END {print sum/1024/1024, "TB"}'
}

function get_asm_disks_size2 ()
{
[ $# -eq 0 ] && echo "Please provide zone name " && return 1
DIDLIST=`zonecfg  -z $1 info device | awk -F"/" '/match/ {print $NF}'| sed 's/s.$//'| xargs` && echo $DIDLIST
DEVLIST=$(for DID in $DIDLIST; do cldev show $DID | grep `uname -n` | sed -n '1p'| awk -F":" '{print $NF}';done|xargs) && echo $DEVLIST
for DISK in $DEVLIST ; do luxadm disp ${DISK}s2 | grep Unformat;done| awk '{sum += $3} END {print sum/1024/1024, "TB"}'
}

function set_decom_linux_vars ()
{
local HOSTNAME
check_root || return 1
export HOSTNAME=`uname -n | cut -d"." -f1` || export HOSTNAME=$1
export TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/${HOSTNAME}
DOMAINNAME=opoce.cec.eu.int
export IP=`dig ${HOSTNAME}.${DOMAINNAME} +short`
export ILO=${HOSTNAME}-sc
OS=`cat /etc/system-release`
SERIAL=`dmidecode -s system-serial-number` 
MANUFACTURER=`dmidecode -s system-manufacturer`
PRODUCTNAME=`dmidecode -s system-product-name | cut -d"-" -f1`
MODEL="$MANUFACTURER $PRODUCTNAME"
export LOCATION=`/home/admin/bin/getcmdb.sh linux | grep $HOSTNAME-sc | cut  -f 5 -d ";"`
echo "
HOSTNAME=               $HOSTNAME
IP=                     $IP
ILO=                    $ILO
OS=                     $OS
SERIAL=                 $SERIAL
LOCATION=               $LOCATION
MODEL=                  $MODEL
"
}

function set_decom_linux_vars_cmdb ()
{
local HOSTNAME
check_root || return 1
[ $# -eq 0 ] && export HOSTNAME=`uname -n | cut -d"." -f1` || export HOSTNAME=$1
export IP=`/home/admin/bin/getcmdb.sh linux | grep $HOSTNAME-sc | cut  -f 2 -d ";"`
export TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/${HOSTNAME}
export ILO=`/home/admin/bin/getcmdb.sh cons | grep $HOSTNAME-sc | awk '{ print $1}' | cut -f 1 -d ";"`
export SYSTEM=`/home/admin/bin/getcmdb.sh linux | grep $HOSTNAME | cut  -f 7 -d ";" |  awk '{print $1,$2;exit}'`
export RELEASE=`/home/admin/bin/getcmdb.sh linux | grep $HOSTNAME | cut  -f 7 -d ";" |  awk '{print $7;exit}'`
export OS="${SYSTEM} ${RELEASE}"
export SERIAL=`/home/admin/bin/getcmdb.sh serial | grep $HOSTNAME | cut  -f 9 -d ";"`
export LOCATION=`/home/admin/bin/getcmdb.sh linux | grep $HOSTNAME-sc | cut  -f 5 -d ";"`
export MODEL=`/home/admin/bin/getcmdb.sh serial | grep $HOSTNAME | awk -F";"  '{print $7 "-" $6}'`
echo "
HOSTNAME=		$HOSTNAME
IP=			$IP
ILO=			$ILO
OS=			$OS
SERIAL=			$SERIAL
LOCATION=		$LOCATION
MODEL=			$MODEL
"
}

function save_decom_linux_vars ()
{
local HOSTNAME
check_root || return 1
export HOSTNAME=`uname -n | cut -d"." -f1` || export HOSTNAME=$1
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/${HOSTNAME}
[ ! -d "$TMP_FOLDER" ] && mkdir $TMP_FOLDER
set_decom_linux_vars | tee ${TMP_FOLDER}/sysinfo_${HOSTNAME}.txt
}

function generate_ip_delete_hostlist_records ()
{
local H BKP
[ $# -eq 0 ] && errmsg "Please provide hosts list" && return 1
for H in $@; do
BKP="bkp-${H}"
generate_ip_delete_host_records $H
generate_ip_delete_host_records $BKP
done
}

function generate_ip_delete_host_records ()
{
    local H DOMAIN HOST ADDR DIGINFO RECORD_TYPE RECORD_VALUE BKPHOST BKPADDR REVERSE
    [ $# -eq 0 ] && return 1
    H=$1
    DOMAIN=.opoce.cec.eu.int
    HOST=${H}${DOMAIN}
    ADDR=`dig ${HOST} +short | sed 's/\.$//'`
    if [ -n "$ADDR" ]; then
      DIGINFO=`dig $HOST | grep "^$HOST" | sed 's/\.$//' | awk '{print $4,$5}'`
      IFS=" " read  -r RECORD_TYPE RECORD_VALUE <<< $DIGINFO
      if [ "$RECORD_TYPE" == "A" ]; then
          REVERSE=`dig -x $ADDR | awk '/'$HOST'/{print $1}'| sed 's/\.$//'`
          printf "%-40s %-12s %s\n" $HOST "A" $ADDR $REVERSE "PTR" $HOST
      elif [ "$RECORD_TYPE" == "CNAME" ]; then
          printf "%-40s %-12s %-40s\n" $HOST "CNAME" $RECORD_VALUE
      fi
    fi
}

print_ip_delete_info ()
{
    local H DOMAIN HOST ADDR DIGINFO RECORD_TYPE RECORD_VALUE BKPHOST BKPADDR
    [ $# -eq 0 ] && return 1
    H=$1
    DOMAIN=.opoce.cec.eu.int
    HOST=${H}${DOMAIN}
    ADDR=`dig ${HOST} +short | sed 's/\.$//'`
    if [ -n "$ADDR" ]; then
      DIGINFO=`dig $HOST | grep "^$HOST" | sed 's/\.$//' | awk '{print $4,$5}'`
      IFS=" " read  -r RECORD_TYPE RECORD_VALUE <<< $DIGINFO
      if [ "$RECORD_TYPE" == "A" ]; then
          BKPHOST="bkp-${HOST}"
          BKPADDR=`dig ${BKPHOST} +short`
          if [ -n "$BKPADDR" ]; then
              printf "%-40s %-12s %-40s %s\n" $HOST "A" $ADDR Delete $BKPHOST "A" $BKPADDR Delete
          else
              printf "%-40s %-12s %-40s %s\n" $HOST "A" $ADDR Delete
          fi
      elif [ "$RECORD_TYPE" == "CNAME" ]; then
          printf "%-40s %-12s %-40s %s\n" $HOST "CNAME" $RECORD_VALUE Delete
      fi
    fi
}

function create_delete_ip_ticket_for_SNET ()
{

[ $# -eq 0 ] && errmsg "Please provide hosts " && return 1

echo "
--------------------------------------------------------------------------------
                           Create the ticket for SNET                           
--------------------------------------------------------------------------------

Title :              OP - IP ADDRESS REQUEST
Description :        Please forward this request to S-NET team.
Attachments :        The Excel file in attachment
Incident type :      REQUEST FOR CHANGE
Configuration Item : DNS INTERNE
System :             SERVICE
Component :          TC-DATA NETWORKS SERVICES
Item :               DNS
Status :             Assigned
Assignment :         DIGIT ISHS SERVICE-DESK or CHD

"
printf "%-40s %-12s %-40s %s\n" Name    Type    Value   Action
for H in $@; do print_ip_delete_info $H;done
}

# Fetch decom info about Linux host

function fetch_decom_info_about_linux_host ()
{
HOSTNAME=`uname -n | cut -d"." -f1`
msgsep "Fetching decom info about server $HOSTNAME"
msgsep "Define the TMP folder"
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/${HOSTNAME}
[ ! -d "$TMP_FOLDER" ] && mkdir $TMP_FOLDER && echo "TMP_FOLDER:=  $TMP_FOLDER"

# Create the sysinfo file (from cmdb)
msgsep "Create the sysinfo file (from cmdb)"
save_decom_linux_vars

# Save HBS WWN's
msgsep "Save HBS WWN's"
cat /sys/class/fc_host/host?/port_name | tee $TMP_FOLDER/hba_wwns_${HOSTNAME}.txt

# Save /etc/hosts
msgsep "Save /etc/hosts"
cat /etc/hosts | tee $TMP_FOLDER/etc_hosts_${HOSTNAME}.txt

# Save IP info
msgsep "Save IP info"
ip a > $TMP_FOLDER/ip_config_${HOSTNAME}.txt

# Get luns
msgsep "Get luns"
# rescan the SCSI bus
for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done
multipath -ll | egrep 'EMC|HITACHI' | sort -k2 | tee $TMP_FOLDER/LUNs_${HOSTNAME}.txt
msg "NB of LUNs" && multipath -ll | grep -c SYMMET

# System product name
msgsep "System product name"
(dmidecode -s system-manufacturer && dmidecode -s system-product-name )| xargs | tee $TMP_FOLDER/product_name_${HOSTNAME}.txt

msgsep "TMP_FOLDER content"
# List $TMP_FOLDER content
ls -lh $TMP_FOLDER
}


