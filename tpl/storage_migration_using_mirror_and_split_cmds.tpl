# Moving the storage from old to new VMAX using the zpool attach to create a mirror and split
----------------------------------------------------------------------------------------------
# Get new LUN

##### variables
export zone_name=<zone_name>
export tmp_folder=/net/nfs-infra.isilon/unix/systemstore/temp/$zone_name
export POOLTOMIGRATE=${zone_name}-<type>
export OLDPOOL=${POOLTOMIGRATE}_old
export POOLTOMIGRATEDISK=                # emcpower58a
export NEWDISK=                          # emcpower97a

# get the pool to migrate disk(s)
POOLTOMIGRATEDISK=`zpool status $POOLTOMIGRATE | awk '/NAME/,0' | egrep -v "NAME|$zone_name|mirror"  | awk '/ONLINE/ {print $1}' | xargs` && echo $POOLTOMIGRATEDISK

NEWDID=d25
NEWDISK=$(awk '/ '$NEWDID' / {print $(NF-8)}' storage_info_`uname -n`.txt | sort -u | xargs) && echo $NEWDISK


echo "$POOLTOMIGRATE $OLDPOOL $zone_name $tmp_folder $NEWDISK $POOLTOMIGRATEDISK"


# add a mirror to the current zpool

# echo zpool import $POOLTOMIGRATE 
echo zpool list $POOLTOMIGRATE
echo zpool attach $POOLTOMIGRATE $POOLTOMIGRATEDISK $NEWDISK
echo zpool status $POOLTOMIGRATE
# Wait until resilvering is finished: status 'ONLINE' insted of 'DEGRADED' during resilvering

# Split the zpool and keep the new disk on the current pool

echo zpool split $POOLTOMIGRATE $OLDPOOL $POOLTOMIGRATEDISK
# Check that the pool to migrate remains with the new disk 
echo zpool status $POOLTOMIGRATE 

# Check the old pool
{
echo zpool import -N $OLDPOOL 
echo zpool status $OLDPOOL
echo zpool export $OLDPOOL 
}

# Test a cluster swith back and forward
# If the zone is working fine, one can delete the old pool and return the old disk(s) to the storage team

