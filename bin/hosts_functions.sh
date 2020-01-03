# hosts_functions.sh

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

function zones_primary_on_current_node ()
{
    for RG in `clrg list`
    do
        echo -n "$RG: " | perl -pe 's/.?rg//g'
        clrg show -p Nodelist $RG | nawk '/Nodelist/ {print $(NF-1)}' | xargs
    done | grep `uname -n` | cut -d':' -f1 | xargs
}

function zones_secondary_on_current_node ()
{
    for RG in `clrg list`
    do
        echo -n "$RG: " | perl -pe 's/.?rg//g'
        clrg show -p Nodelist $RG | nawk '/Nodelist/ {print $NF}' | xargs
    done | grep `uname -n` | cut -d':' -f1 | xargs
}

function get_zone_primary_and_secondary_hosts ()
{
check_input $@ || return 1
echo -n "Primary host for $1: " && cmdb zone| grep $1\; | awk -F";" '/Primary/ {print $7}'
echo -n "Secondary host for $1: " && cmdb zone| grep $1\; | awk -F";" '/Secondary/ {print $7}'
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

function count_all ()
{
for i in linuxphys solarisphys solariszones linuxvm oracle opsrv; do count_$i;done
}

