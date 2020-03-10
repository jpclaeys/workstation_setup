function unmanage_running_zones ()
{
ZL=`zoneadm list -v| egrep -v "NAME|global"| awk '{print $2}'`&& echo $ZL
for zone_name in $ZL; do
echo "clrg offline ${zone_name}-rg && clrs list -g ${zone_name}-rg | xargs clrs disable && clrg unmanage ${zone_name}-rg && clrg status ${zone_name}-rg"
done
}

function restart_unmanaged_zones ()
{
[ $# -eq 0 ] && echo "PLease specify zone(s)" && return 1
ZL="$@"
for zone_name in $ZL; do
echo "clrg manage ${zone_name}-rg && clrg status ${zone_name}-rg && clrg online -e ${zone_name}-rg && clrg status ${zone_name}-rg"
done
echo zoneadm list -civ
}

function unmanage_zone ()
{
# Parameter: <zone_name>
check_input $@ || return 1
validatehost $1 || return 1
zone_name=$1
CMD="clrg offline ${zone_name}-rg && clrs list -g ${zone_name}-rg | xargs clrs disable && clrg unmanage ${zone_name}-rg && zoneadm -z ${zone_name} list -v && clrg status ${zone_name}-rg"
confirmexecution $CMD && eval $CMD
}

function satellite_host_list ()
{
[ "`uname -n`" != "satellite-pk" ] && errmsg "Need to be on satellite-pk" && return 1
#[ `whoami` != "root" ] && echo "Need to be root" && return 1
unset http_proxy
local HL FILTER
if [ ! -z $1 ]; then
#  hammer --csv host list --search="name ~ $1"
  HL="$@"
#  FILTER=`echo $HL| sed 's/ /|/g'` && echo "Hosts filter:= $FILTER"
  FILTER=`echo $HL| sed 's/ /.op|/g;s/$/.op/'` && echo "Hosts filter:= $FILTER"
  hammer --csv host list --search=$FILTER
else
  hammer --csv host list | grep -v virt-who
fi
}

function satellite_delete_host ()
{
[ "`uname -n`" != "satellite-pk" ] && errmsg "Need to be on satellite-pk" && return 1
#[ `whoami` != "root" ] && echo "Need to be root" && return 1
[ $# -eq 0 ] && errmsg "Please provide hostname(s)" && return 1
unset http_proxy
local HL FILTER
#satellite_host_list $@
HL="$@"
#FILTER=`echo $HL| sed 's/ /|/g'` && echo "Hosts filter:= $FILTER"
FILTER=`echo $HL| sed 's/ /.op|/g;s/$/.op/'` && echo "Hosts filter:= $FILTER"
hammer --csv host list --search=$FILTER
cmds=("") && cmdindex=0
for ID in $(hammer --csv host list --search=$FILTER | grep -vi '^ID' | awk -F, {'print $1'})
  do
    cmds[$cmdindex]="hammer host delete --id $ID"
    cmdindex=$((cmdindex + 1))
done
executeCMDs "${cmds[@]}"
}

