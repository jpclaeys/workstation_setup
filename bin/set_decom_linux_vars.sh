function set_decom_linux_vars ()
{
[ $# -eq 0 ] && export HOST_NAME=`uname -n | cut -d"." -f1` || export HOST_NAME=$1
msg "Get IP"
export IP=`/home/admin/bin/getcmdb.sh linux | grep $HOST_NAME-sc | cut  -f 2 -d ";"`
msg "Get TMP folder"
export TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/${HOST_NAME}
msg "Get ILO"
export ILO=`/home/admin/bin/getcmdb.sh cons | grep $HOST_NAME-sc | awk '{ print $1}' | cut -f 1 -d ";"`
msg "Get system"
export SYSTEM=`/home/admin/bin/getcmdb.sh linux | grep $HOST_NAME | cut  -f 7 -d ";" |  awk '{print $1,$2;exit}'`
msg "Get Release"
export RELEASE=`/home/admin/bin/getcmdb.sh linux | grep $HOST_NAME | cut  -f 7 -d ";" |  awk '{print $7;exit}'`
msg "Get OS"
export OS="${SYSTEM} ${RELEASE}"
msg "Get Serial number"
export SERNUMB_CHASSIS=`/home/admin/bin/getcmdb.sh serial | grep $HOST_NAME | cut  -f 9 -d ";"`
msg "Get Location"
export LOCATION=`/home/admin/bin/getcmdb.sh linux | grep $HOST_NAME-sc | cut  -f 5 -d ";"`
msg "Get Model"
#export MODEL=`/home/admin/bin/getcmdb.sh linux | grep $HOST_NAME-sc | cut  -f 10 -d ";"`
export MODEL=`/home/admin/bin/getcmdb.sh serial | grep $HOST_NAME | awk -F";"  '{print $7 "-" $6}'`
echo "
HOST_NAME=		$HOST_NAME
IP=			$IP
ILO=			$ILO
OS=			$OS
SERIAL=			$SERNUMB_CHASSIS
LOCATION=		$LOCATION
MODEL=			$MODEL
"
}


function save_decom_linux_vars ()
{
check_root || return 1
[ $# -eq 0 ] && export HOST_NAME=`uname -n | cut -d"." -f1` || export HOST_NAME=$1
TMP_FOLDER=/net/nfs-infra.isilon/unix/systemstore/temp/${HOST_NAME}
[ ! -d "$TMP_FOLDER" ] && mkdir $TMP_FOLDER
set_decom_linux_vars $HOST_NAME | tee ${TMP_FOLDER}/sysinfo_${HOST_NAME}.txt
}
