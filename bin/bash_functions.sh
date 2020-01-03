# bash_functions.sh

function startxpraserver ()
{
PORT=${1:-6007}
# Note: type xrandr without any argument in order to see the available screen resolutions
#xpra start-desktop --start-child=mate-session --start="xrandr -s 1280x1024" --exit-with-children --idle-timeout=0 --server-idle-timeout=0 :2000
#xpra start-desktop --start-child=mate-session --start="xrandr -s 1908x1115" --exit-with-children --idle-timeout=0 --server-idle-timeout=0 :2000
# xpra start :2000 &
xpra --pulseaudio=no --daemon=no start :$PORT &
}

function killxpraserver ()
{
PORT=${1:-6007}
#XPRA=`ps -fuclaeyje | grep start-desktop | grep -v grep| head -1 | xargs` && [ -n "$XPRA" ] && echo $XPRA
XPRA=`ps -fuclaeyje | awk '/start/ && /'$PORT'/' | grep -v awk ` && [ -n "$XPRA" ] && echo $XPRA
[ -z "$XPRA" ] && return 1
CMD=`echo $XPRA  | awk '{print $2}' | xargs echo kill` # && echo $CMD
echo
confirmexecution $CMD && eval $CMD
}

function snapshotsize()
{
MB=`zfs list -t snapshot | awk '$2 ~ /M/'   | sed 's/M//' | awk '{sum+=$2}END{print sum/1024}'`
[ -n "$MB" ] && MB=0
zfs list -t snapshot | awk '$2 ~ /G/'   | sed 's/G//' | nawk -v mb=$MB '{sum+=$2}END{print sum+mb " GB"}'
}

function useduid()
# return 1 if the Uid is already used, else 0
{
    if [ -z "$1" ]
    then
    return
    fi
    for i in ${lines[@]} ; do
        if [ $i == $1 ]
        then
        return 1
    fi
    done
return 0
}

function get_first_free_local_uid ()
{   
#    [ `uname -n` != "$ADMINWST" ] && errmsg "You need to be on $ADMINWST" && return 1
    baseuid=${1:-81935} 
    lines=(`s infra2-pk egrep . /applications/explo/data/opappexplo/latest/*/host/etc/passwd| awk -F":" '{print $4,$5,$2}'| awk -v base=$baseuid '$1>base {print $1}'| sort -u | head -100`) && echo -e "\n#==> All local uids above $baseuid:\n${lines[@]}"
    x=1
    while [ $x -eq 1 ]; do
        baseuid=$(( $baseuid + 1))
        useduid $baseuid
        x=$?
    done 
    echo -e "\n#==> First free uid: $baseuid"
}

function get_first_free_ldap_uid ()
{
#    [ `uname -n` != "$ADMINWST" ] && errmsg "You need to be on $ADMINWST" && return 1
    baseuid=${1:-30001}
    lines=(`s infra2-pk ldapsearchalluidNumbers | awk -v base=$baseuid '$1>base  {print $1}' | sort`) && echo -e "\n#==> All ldap uids above $baseuid:\n${lines[@]}"
    x=1
    while [ $x -eq 1 ]; do
        baseuid=$(( $baseuid + 1))
        useduid $baseuid
        x=$?
    done
    echo -e "\n#==> First free uid: $baseuid"
}

function get_first_free_uid ()    
{   
#    [ `uname -n` != "$ADMINWST" ] && errmsg "You need to be on $ADMINWST" && return 1
    baseuid=${1:-81935}
    LOCALUIDS=(`s infra2-pk egrep . /applications/explo/data/opappexplo/latest/*/host/etc/passwd| awk -F":" '{print $4,$5,$2}'| awk -v base=$baseuid '$1>base  {print $1}' | sort -u | head -100 `) 
    LDAPUIDS=(`s infra2-pk ldapsearchalluidNumbers | awk -v base=$baseuid '$1>base  {print $1}' | sort`)
    lines=(`echo ${LOCALUIDS[@]} ${LDAPUIDS[@]} | tr ' ' '\012' | sort -u`) && echo -e "\n#==> All uids above $baseuid:\n${lines[@]}"
    x=1
    while [ $x -eq 1 ]; do
        baseuid=$(( $baseuid + 1))
        useduid $baseuid
        x=$?
    done 
    echo -e "\n#==> First free uid: $baseuid"
}

function check_if_uid_exist ()
{
[ $# -eq 0 ] && echo "Usage: $FUNCNAME <userid>" && return 1
id $1
msg "Checking in local users"
s infra2-pk egrep -i $1 /applications/explo/data/opappexplo/latest/*/host/etc/passwd | sed 's/\./:/g'| awk -F":" '{print $7, $9,$2}'
msg "Checking in ldap users"
s infra2-pk ldapsearchalluidNumbersanduid | grep $1
}

function get_all_storage_info ()
{
tmp_folder=${UNIXSYSTEMSTORE}/temp/storage_info
cmd="/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_\`uname -n\`.txt" && echo "cmd: $cmd"
for H in `thosts`; do msggreen $H && sre $H $cmd;done
}

function powercut_offline_nonprod_rg ()
{
zonesnoprodlocal
if [ -n "$HL" ]; then
RGL=`echo $HL| sed 's/ /-rg /g;s/$/-rg/'`
RGLS=`echo $RGL | sed 's/ /,/g'`
echo "# Check the RGs status"
echo show_RGstatus $RGL
echo "# Cmds to execute:"
echo "# Disable the resources"
#for RG in $RGL; do
#echo clrs disable `clrs list -g $RG | xargs`
#echo clrs disable -g $RG +
#done
echo clrs disable -g $RGLS +
echo "# Check the resources status"
echo show_RSstatus $RGL
echo "# Offline the RG"
echo clrg offline $RGL
echo "# Unmanage the RGs"
echo clrg unmage  $RGL
echo "# Check the RGs status"
echo show_RGstatus $RGL
echo "# Show RG managed state"
echo show_RGstate $RGL
else
  echo "There are no running non-production zones"
fi
}

function powercut_switch_prod_RG_to_other_node ()
{
#echo "# All zones: `zoneadm list | grep -v global | xargs`"
echo "# Cluster name: `cluster list`"
OTHERNODE=`clnode list| grep -v $(uname -n)` && echo "# Other node: $OTHERNODE"
zonesprodlocal
if [ -n "$HL" ]; then
RGL=`echo $HL| sed 's/ /-rg /g;s/$/-rg/'`
echo "# Check the RGs status"
echo show_RGstatus $RGL
echo "# Switch th RGs to the other node"
echo clrg switch -n $OTHERNODE $RGL
echo "# Check the RGs status"
echo show_RGstatus $RGL
else
  echo "There are no running production zones"
fi
}

function  powercut_restart_unmanaged_RGs ()
{
if [ -n "$HL" ]; then
RGL=`echo $HL| sed 's/ /-rg /g;s/$/-rg/'`
echo "# Check the RG status"
echo show_RGstatus $RGL
echo "# Bring the resource groups online, place them in a manage state and enable the cluster resources"
NODE=`uname -n`
echo clrg online -M -e -n $NODE $RGL
echo "# Check the RG status"
echo show_RGstatus $RGL
else
  echo "There are no non prod zones"
fi
}

function powercut_switch_back_prod_to_mer ()
{
if [ -n "$HL" ]; then
RGL=`echo $HL| sed 's/ /-rg /g;s/$/-rg/'`
echo "# Check the RG status"
echo show_RGstatus $RGL
echo "# switch back the production zones to MER"
NODE=`uname -n`
echo clrg switch -n $NODE $RGL
echo "# Check the RG status"
echo show_RGstatus $RGL
else
  echo "There are no prod zones"
fi
}

function show_unmanaged_RG ()
{
clrg show | egrep 'Resource Group:|RG_state:' | xargs -L2 | nawk '/Unmanaged/ {print $3}' | xargs
}

function show_managed_RG ()
{
clrg show | egrep 'Resource Group:|RG_state:' | xargs -L2 | nawk '/Managed/ {print $3}' | xargs
}

function show_RGstate ()
{
local printout TITLE TITLESUBLINE
printout="nawk '{printf \"%-20s%-s\\n\",\$1,\$2}'"
TITLE="Group state"
TITLESUBLINE=`echo $TITLE | tr '[:upper:]' '[:lower:]'| sed 's/[a-z]/-/g'`
echo -e "$TITLE\n$TITLESUBLINE" | eval $printout
clrg show $@ | egrep 'Resource Group:|RG_state:'| xargs -L2 | nawk '{print $3,$NF}' | eval $printout | sort
}

function show_RGstatus ()
{
local printout TITLE TITLESUBLINE
printout="nawk '{printf \"%-20s%-12s%-12s%-12s%-9s\\n\",\$1,\$2,\$3,\$4,\$5}'" 
TITLE="Group Node Status Node Status"
TITLESUBLINE=`echo $TITLE | tr '[:upper:]' '[:lower:]'| sed 's/[a-z]/-/g'`
echo -e "$TITLE\n$TITLESUBLINE" | eval $printout
clrg status $@ | grep . | sed '1,/---/d' | xargs -L2 | awk '{print $1,$2,$4,$5,$NF}' | eval $printout | sort -k3
}

function show_RSstatus ()
{
local printout TITLE TITLESUBLINE

if [ $# -eq 0 ]; then
    ARGS=
  else
    ARGS="-g `echo $@ | sed 's/ /,/g'`"
fi
printout="nawk '{printf \"%-20s%-12s%-24s%-12s%-12s\\n\",\$1,\$2,\$3,\$4,\$5}'"
TITLE="Resource Node State Node State"
TITLESUBLINE=`echo $TITLE | tr '[:upper:]' '[:lower:]'| sed 's/[a-z]/-/g'`
echo -e "$TITLE\n$TITLESUBLINE" | eval $printout
clrs status $ARGS | grep . | sed '1,/---/d' | xargs -L2 | nawk '{print $1,$2,$3,$5,$6}' | eval $printout
}
function fixsrdf ()
{
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <disk group> " && return 1
DG=$1
echo symdg_personality_info $DG
#echo symrdf -g $DG query
echo "symrdf -g $DG swap -nop && symdg_personality_info $DG"
echo symrdf -g $DG establish -nop
echo symdg_personality_info $DG
}

function verify_srdf_dg ()
{
for DG in `cldg list`; do symrdf -g $DG verify;done
}

function verify_srdf_personality ()
{
for DG in `cldg list`; do symdg_personality_info $DG ;done
}

function upload_file_to_oracle ()
{
[ $# -ne 2 ] && msg "Usage: $FUNCNAME <file> <SR>" && return 1
FILE=$1
SR=$2
CMD="curl -k -T $FILE -o /tmp/out -x http://pslux.ec.europa.eu:8012/ -U a0029ffb:iufjSEP -u opdl-infra-systems@publications.europa.eu https://transport.oracle.com/upload/issue/$SR/"
confirmexecution $CMD && eval $CMD
}

function get_display_manager ()
{
[ `whoami` != "root" ] && echo "Need to be root" && return 1
x=$(lsof -F '' /tmp/.X11-unix/X0 2>/dev/null); x=${x#p}
ps -p $(ps -o ppid -hp $x)
}

function linuxinfo ()
{
echo -e "\n#===> Linux version <===\n" && uname -a
echo -e "\n\n#===> System Release <===\n" && cat /etc/system-release
echo -e "\n#===> IP @ <===\n" && ip a
echo -e "\n#===> lsblk  <===\n" && lsblk
echo -e "\n#===> pvs <===\n" && pvs
echo -e "\n#===> vgs <===\n" && vgs
echo -e "\n#===> lvs <===\n" && lvs
echo -e "\n#===> df -h <===\n" && df -h
echo -e "\n#===> fstab <===\n" && cat /etc/fstab
}

