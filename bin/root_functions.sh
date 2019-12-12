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
