[ `uname -s` == "SunOS" ] && alias awk=nawk

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

function hostslists (){
CMDBHOST=/tmp/cmdbhost$$
cmdb host > $CMDBHOST
# T-series
HLTMER=(`awk -F";" '/t[45]/&&/MER/ {print $1}' $CMDBHOST | xargs`) # && echo ${HLTMER[@]}
HLTEUFO=(`awk -F";" '/t[45]/&&/EUFO/ {print $1}' $CMDBHOST | xargs`) # && echo ${HLTEUFO[@]}
HLT=(${HLTMER[@]} ${HLTEUFO[@]}) # && echo ${HLT[@]}

echo "
T MER  (${#HLTMER[@]}): ${HLTMER[@]}
T EUFO (${#HLTEUFO[@]}): ${HLTEUFO[@]}
T ALL (${#HLT[@]}): ${HLT[@]}
"
rm $CMDBHOST
}

function tchassis () {
  TCONSL=`cmdb cons| awk -F";" '/t[45]/ {print $1}' | tr '\012' ' '`
  [ $# -eq 0 ] && echo $TCONSL
}

function tdomainsperchassis () {
  tchassis n
  CMDBHOST=/tmp/cmdbhost$$
  cmdb host > $CMDBHOST
  for CONS in $TCONSL; do echo $CONS && \grep $CONS $CMDBHOST;done
  rm $CMDBHOST
}

function consoles () {
  tchassis n
  CMDBHOST=/tmp/cmdbhost$$ && CMDBCONS=/tmp/cmdbcons$$
  cmdb cons > $CMDBCONS
  cmdb host > $CMDBHOST
  for CONS in $TCONSL; do
     LOCATION=`awk -F";" '/'$CONS'/ {print $3}' $CMDBCONS |cut -d" " -f1`
     DOM0=`awk -F";" '/'$CONS'/&&/Domain 0/ {print $(NF-2),$1}' $CMDBHOST`
     DOM1=`awk -F";" '/'$CONS'/&&/Domain 1/ {print $(NF-2),$1}' $CMDBHOST`
     printf "%-10s %-5s %-20s %-20s\n" $CONS $LOCATION "$DOM0" "$DOM1"
     done | sed 's/MER/AMER/' | sort -k2 | sed 's/AMER/MER/'
     rm $CMDBHOST ; rm $CMDBCONS
}

function tclusters () {
  HLT=`cmdb host | awk -F";" '/t[45]/ {print $1}' | tr '\012' ' '` # && echo $HLT
  for H in $HLT; do  ssh $H /usr/cluster/bin/clnode list|sort| tr '\012' ' '&& echo;done| sort -u
}

function thosts () {
THOSTS=`cmdb host | awk -F";" '$(NF-3) ~ "T[45]" {print $1}' | xargs` && echo $THOSTS
}

function t4hosts () {
T4HOSTS=`cmdb host | awk -F";" '$(NF-3) ~ "T4" {print $1}' | xargs` && echo $T4HOSTS
T4PATTERN=`echo $T4HOSTS|sed 's/ /|/g'` # && echo $T4PATTERN
}

function t5hosts () {
T5HOSTS=`cmdb host | awk -F";" '$(NF-3) ~ "T5" {print $1}' | xargs` && echo $T5HOSTS
T5PATTERN=`echo $T5HOSTS|sed 's/ /|/g'` # && echo $T5PATTERN
}

function t52hosts () {
cmdb host | awk -F";" '$(NF-3) ~ "T52" {print $1}' | xargs
}

function t52hostsmer () {
cmdb host | awk -F";" '($(NF-3) ~ "T52") && (substr($5,0,3) ~ "MER") {print $1}' | xargs
}

function t52hostseufo () {
cmdb host | awk -F";" '($(NF-3) ~ "T52") && (substr($5,0,3) ~ "EUF") {print $1}' | xargs
}

function t54hosts () {
cmdb host | awk -F";" '$(NF-3) ~ "T54" {print $1}' | xargs
}

function t54hostsmer () {
cmdb host | awk -F";" '($(NF-3) ~ "T54") && (substr($5,0,3) ~ "MER") {print $1}' | xargs
}

function t54hostseufo () {
cmdb host | awk -F";" '($(NF-3) ~ "T54") && (substr($5,0,3) ~ "EUF") {print $1}' | xargs
}

function thostsmer () {
cmdb host| awk -F";" "/MER/ {print \$1}" | xargs
}

function thostsprimary () {
cmdb host| awk -F";" "/Domain 0/ {print \$1}" | xargs
}

function thostssecondary () {
cmdb host| awk -F";" "/Domain 1/ {print \$1}" | xargs
}

function thostsmerprimary () {
cmdb host| awk -F";" "/MER/&&/Domain 0/ {print \$1}" | xargs
}

function thostsmersecondary () {
cmdb host| awk -F";" "/MER/&&/Domain 1/ {print \$1}" | xargs
}

function thostseufo () {
cmdb host| awk -F";" "/EUFO/ {print \$1}" | xargs
}

function thostseufoprimary () {
cmdb host| awk -F";" "/EUFO/&&/Domain 0/ {print \$1}" | xargs
}

function thostseufosecondary () {
cmdb host| awk -F";" "/EUFO/&&/Domain 1/ {print \$1}" | xargs
}

function t4zonescmdb () {
t4hosts > /dev/null
zoneslist $T4HOSTS
}

function t5zonescmdb () {
t5hosts > /dev/null
zoneslist $T5HOSTS
}

function t5zones () {
echo -n "Total T5 zones: " && mypssH "`t5hosts`" '(/sbin/zoneadm list| grep -v global)' | grep -v '\[' | wc -l && mypssH "`t5hosts`" '(/sbin/zoneadm list| grep -v global | sort | xargs)'
}

function t52zones () {
echo -n "Total T52 zones: " && mypssH "`t52hosts`" '(/sbin/zoneadm list| grep -v global)' | grep -v '\[' | wc -l && mypssH "`t52hosts`" '(/sbin/zoneadm list| grep -v global | sort | xargs)'
}

function t54zones () {
echo -n "Total T54 zones: " && mypssH "`t54hosts`" '(/sbin/zoneadm list| grep -v global)' | grep -v '\[' | wc -l && mypssH "`t54hosts`" '(/sbin/zoneadm list| grep -v global | sort | xargs)'
}

function zonesprod ()
{
#for H in `thosts`; do msggreen $H && s $H zoneadm list | egrep -v 'globa' | egrep  'opgtw$|pz';done
mypssH "`thosts`" '(/usr/sbin/zoneadm list | grep -v global| egrep  "opgtw\$|pz";:)'
}

function zonesprodcount ()
{
#for H in `thosts`; do s $H zoneadm list | egrep -v 'globa' | egrep  'opgtw$|pz';done | wc -l
zonesprod | grep -v "\[" | wc -l
}

function zonesnoprod ()
{
#for H in `thosts`; do msggreen $H && s $H zoneadm list | egrep -v 'globa' | egrep -v 'opgtw$|pz';done
mypssH "`thosts`" '(/usr/sbin/zoneadm list | grep -v global| egrep  -v "opgtw\$|pz";:)'
}

function zonesnoprodcount ()
{
#for H in `thosts`; do s $H zoneadm list | egrep -v 'globa' | egrep -v 'opgtw$|pz';done | wc -l
zonesnoprod | grep -v "\[" | wc -l
}

function zonesmer ()
{
#for H in `thostsmer`; do msggreen $H && s $H zoneadm list | egrep -v 'globa';done
mypssH "`thostsmer`" '(/usr/sbin/zoneadm list | egrep -v global;:)'
}

function zonesprodmer ()
{
#for H in `thostsmer`; do msggreen $H && s $H zoneadm list | egrep -v 'globa' | egrep  'opgtw$|pz';done
mypssH "`thostsmer`" '(/usr/sbin/zoneadm list | egrep -v global | egrep  "opgtw\$|pz";:)'
}

function zonesprodmercount ()
{
#for H in `thostsmer`; do s $H zoneadm list | egrep -v 'globa' | egrep  'opgtw$|pz';done | wc -l
zonesprodmer | grep -v "\[" | wc -l
}

function zonesnoprodmer ()
{
#for H in `thostsmer`; do msggreen $H && s $H zoneadm list | egrep -v 'globa' | egrep -v 'opgtw$|pz';done
mypssH "`thostsmer`" '(/usr/sbin/zoneadm list | egrep -v global | egrep  -v "opgtw\$|pz";:)'
}

function zonesnoprodmercount ()
{
#for H in `thostsmer`; do s $H zoneadm list | egrep -v 'globa' | egrep -v 'opgtw$|pz';done | wc -l
zonesnoprodmer | grep -v "\[" | wc -l
}

function zoneseufo ()
{
#for H in `thostseufo`; do msggreen $H && s $H zoneadm list | egrep -v 'globa';done
mypssH "`thostseufo`" '(/usr/sbin/zoneadm list | egrep -v global;:)'
}

function zonesprodeufo ()
{
#for H in `thostseufo`; do msggreen $H && s $H zoneadm list | egrep -v 'globa' | egrep  'opgtw$|pz';done
mypssH "`thostseufo`" '(/usr/sbin/zoneadm list | egrep -v global | egrep  "opgtw\$|pz";:)'
}

function zonesprodeufocount ()
{
#for H in `thostseufo`; do s $H zoneadm list | egrep -v 'globa' | egrep  'opgtw$|pz';done | wc -l
zonesprodeufo | grep -v "\[" | wc -l
}

function zonesnoprodeufo ()
{
#for H in `thostseufo`; do msggreen $H && s $H zoneadm list | egrep -v 'globa' | egrep -v 'opgtw$|pz';done
mypssH "`thostseufo`" '(/usr/sbin/zoneadm list | egrep -v global | egrep  -v "opgtw\$|pz";:)'
}

function zonesnoprodeufocount ()
{
#for H in `thostseufo`; do s $H zoneadm list | egrep -v 'globa' | egrep -v 'opgtw$|pz';done | wc -l
zonesnoprodeufo | grep -v "\[" | wc -l
}

function zones ()
{
mypssH "`thosts`" '(/usr/sbin/zoneadm list | egrep -v global;:)'
}

function zonescount ()
{
#for H in `thosts`; do s $H zoneadm list | egrep -v 'globa';done | wc -l
zones | grep -v "\[" | wc -l
}

function zonesmercount ()
{
#for H in `thostsmer`; do s $H zoneadm list | egrep -v 'globa';done | wc -l
zonesmer | grep -v "\[" | wc -l
}

function zoneseufocount ()
{
#for H in `thostseufo`; do s $H zoneadm list | egrep -v 'globa';done | wc -l
zoneseufo | grep -v "\[" | wc -l
}

function zonesprodlocal ()
{
HL=`zoneadm list | egrep -v 'globa' | egrep 'opgtw$|pz' | xargs` && [ -n "$HL" ] && echo "HL=\"$HL\""
}

function zonesnoprodlocal ()
{
HL=`zoneadm list | egrep -v 'globa' | egrep -v 'opgtw$|pz' | xargs` && [ -n "$HL" ] && echo "HL=\"$HL\""
}

function zoneslistprod ()
{
mypssH "`thosts`" /usr/sbin/zoneadm list | egrep -v 'globa' | egrep 'opgtw$|pz' | xargs
}

function zoneslistnoprod ()
{
mypssH "`thosts`" /usr/sbin/zoneadm list | egrep -v 'globa' | egrep -v '\[|opgtw$|pz' | xargs
}

function zoneslistall ()
{
mypssH "`thosts`" /usr/sbin/zoneadm list | egrep -v 'globa' | egrep -v '\[' | xargs
}

function zoneslist () {
local HL PATTERN 
[ $# -eq 0 ] && echo "Please provide hosts list" && return 1
HL="$@"
PATTERN=`echo $HL |sed 's/ /|/g'` # && echo $PATTERN
ZFILE=/tmp/zone_entries$$
t4hosts > /dev/null
cmdb zone | grep -v ^ZONE | awk -F";" '/'$PATTERN'/ {print }' > $ZFILE
UNIQZ=`cat $ZFILE| awk -F";" '{print $1}' | sort -u |xargs` # && echo $UNIQZ
NOFOZ= && FOZ= && for Z in $UNIQZ; do [ `grep -c $Z\; $ZFILE` -eq 2 ] && FOZ+=" $Z" || NOFOZ+=" $Z";done
UNIQZA=($UNIQZ)
FOZA=($FOZ)
NOFOZA=($NOFOZ)
echo "
FOZ (${#FOZA[@]}): $FOZ

NOFOZ (${#NOFOZA[@]}): $NOFOZ

UNIQZ (${#UNIQZA[@]}): $UNIQZ
"
rm $ZFILE
}

function allzones_cmdb ()
{
ALLZONES=(`cmdb zone | grep -v ^ZONE | awk -F";" '{print $1}' | sort -u`)
echo "ALLZONES (${#ALLZONES[@]}): ${ALLZONES[@]}"
}

function thoststype () {
thosts > /dev/null
CMDBHOST=/tmp/cmdbhost$$
cmdb host > $CMDBHOST
for H in $THOSTS; do echo -n "$H: " && awk -F";" '/'$H'/ {print $4}' $CMDBHOST;done
rm $CMDBHOST
}

function zonestats ()
{
ZONEFILTER=${1:-seicr}
INTERVAL=${2:-3600}
DURATION=${3:-48}
#echo "$ZONEFILTER $INTERVAL $DURATION"
TIMESTAMP="`date "+%d%m%Y%H%M%S"`"
ZL=`cmdb zone | grep $ZONEFILTER | awk -F";" '{print $1}' | sort -u | xargs` && echo "# $ZL"
for Z in $ZL; do 
# Get the golbalzone name
H=`s $Z eeprom oem-banner | awk -F"=" '{print $NF}'` 
LOG=${Z}_${H}_zonestat_${TIMESTAMP}.log
CMD="nohup ssh -q $H zonestat -q -R high,average -z $Z $INTERVAL $DURATION > $LOG &" && echo $CMD
done
echo exit
}

function zones_primary ()
{
[ $# -eq 0 ] && errmsg "Please enter the host name" && return 1
msg "Show the Primary host for the zones on $1"
msg "Cluster config"
s $1 '(for Z in `zoneadm list -c| grep -v glob`; do clrg show -p Nodelist ${Z}-rg 2>/dev/null|grep -v Groups|xargs;done|grep .)'
msg "cmdb config"
for Z in `s $1 zoneadm list -c| grep -v glob`; do cmdb zone | awk -F";" '/'$Z';/ && /Primary/ {print $1, $7}';done
}

zones_primary_on_current_node ()
{
    for RG in `clrg list`
    do
        echo -n "$RG: " | perl -pe 's/.?rg//g'
        clrg show -p Nodelist $RG | nawk '/Nodelist/ {print $(NF-1)}' | xargs
    done | grep `uname -n` | cut -d':' -f1 | xargs
}

zones_secondary_on_current_node ()
{
    for RG in `clrg list`
    do
        echo -n "$RG: " | perl -pe 's/.?rg//g'
        clrg show -p Nodelist $RG | nawk '/Nodelist/ {print $NF}' | xargs
    done | grep `uname -n` | cut -d':' -f1 | xargs
}

function snapshotsize()
{
MB=`zfs list -t snapshot | awk '$2 ~ /M/'   | sed 's/M//' | awk '{sum+=$2}END{print sum/1024}'`
[ -n "$MB" ] && MB=0
zfs list -t snapshot | awk '$2 ~ /G/'   | sed 's/G//' | nawk -v mb=$MB '{sum+=$2}END{print sum+mb " GB"}'
}

function get_zone_primary_and_secondary_hosts ()
{
check_input $@ || return 1
echo -n "Primary host for $1: " && cmdb zone| grep $1\; | awk -F";" '/Primary/ {print $7}'
echo -n "Secondary host for $1: " && cmdb zone| grep $1\; | awk -F";" '/Secondary/ {print $7}'
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

function show_running_zones ()
{
mypssH "`thosts`" '(/usr/sbin/zoneadm list | grep -v global;:)'
}

function show_running_zones_t52 ()
{
mypssH "`t52hosts`" '(/usr/sbin/zoneadm list | grep -v global;:)'
}

function show_running_zones_t54 ()
{
mypssH "`t54hosts`" '(/usr/sbin/zoneadm list | grep -v global;:)'
}

function show_running_zones_count ()
{
mypssH "`thosts`" '(/usr/sbin/zoneadm list | grep -v global;:)' | grep -v SUCCESS | wc -l
}

function show_running_zones_t52_count ()
{
mypssH "`t52hosts`" '(/usr/sbin/zoneadm list | grep -v global;:)' | grep -v SUCCESS | wc -l
}

function show_running_zones_t54_count ()
{
mypssH "`t54hosts`" '(/usr/sbin/zoneadm list | grep -v global;:)' | grep -v SUCCESS | wc -l
}

function show_non_running_zones ()
{
mypssH "`thosts`"  '(source ./.bashrc;show_RGstatus| grep -iv online;:)'
}

function zonerun ()
{
PATH=/usr/bin:/usr/sbin
verbose=0
if [ "$1" = "-v" ]; then
shift; verbose=1
fi

for zone in `zoneadm list`
do
if [ "$zone" = "global" ]; then continue; fi
if [ $verbose -eq 1 ]; then
echo $zone,
zlogin -S $zone "$*" | sed 's/^/ /'
else
zlogin -S $zone "$*"
fi
done
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
function count_linuxphys ()
{
printf "%-12s: %s\n" linuxphys $(fping  2>/dev/null `cmdb serial | egrep -v 'Solaris|NAME|HOST' | awk -F';' '{print $1}' | sort -u`| grep -c alive)
}

function count_solarisphys ()
{
printf "%-12s: %s\n" solarisphys $(fping 2>/dev/null `cmdb serial | egrep  'Solaris' | awk -F';' '{print $1}' | sort -u`| grep -c alive)
}

function count_solariszones ()
{
#printf "%-12s: %s\n" zones $(fping 2>/dev/null `cmdb zone | egrep  'Solaris' | awk -F';' '{print $1}' | sort -u`| grep -c alive)
printf "%-12s: %s\n" zones `zonescount`
}

function count_linuxvm ()
{
printf "%-12s: %s\n" linuxvm $(fping 2>/dev/null `cmdb linuxvm | egrep -v 'HOST|NAME' | awk -F';' '{print $1}' | sort -u` | grep -c alive)
}

function count_oracle ()
{
printf "%-12s: %s\n" oracle $(fping 2>/dev/null `cmdb oracle | egrep -v 'Server|HOST|NAME' | awk -F';' '{print $1}' | sort -u` | grep -c alive)
}

function count_opsrv ()
{
printf "%-12s: %s\n" opsrv $(fping 2>/dev/null `cmdb opsrv | egrep -v 'HOST|NAME' | awk -F';' '{print $1}'| sort -u` | grep -c alive)
}

function count_all 
{
for i in linuxphys solarisphys solariszones linuxvm oracle opsrv; do count_$i;done
}

