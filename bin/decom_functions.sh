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
export SERNUMB_CHASSIS=`cmdb serial | grep $HOST_NAME | cut  -f 9 -d ";"`
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
SERIAL#     $SERNUMB_CHASSIS
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

function prsingleline () {
    echo "#-------------------- $1  --------------------"
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
 `echo "SERIAL# : " $SERNUMB_CHASSIS`
EOT
prsingleline sysinfo_${HOST_NAME}
cat $TMP_FOLDER/sysinfo_${HOST_NAME}.txt
      
# Gather IP info

getent hosts  | grep -v `clnode list | grep -v $HOST_NAME` | grep -v localhost | grep -v `cat /etc/hosts  | grep -i quorum | awk '{print $2}' ` > ${TMP_FOLDER}/network_ip.txt
echo "`nslookup bkp-${HOST_NAME} |  grep -n Address | grep 6: |awk '{print $2}' `   bkp-${HOST_NAME}  " >> ${TMP_FOLDER}/network_ip.txt

prsingleline "# Network_ip"
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


