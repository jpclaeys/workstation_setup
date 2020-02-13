# shrink with zfs snapshot/send/receive from an old to a new zpool
##############################################################################################################################################

#
# Ask for LUNs, create a new pool
#

DATARDF=emcpower19a
DATAPOOL=${zone_name}-data
NEWDATAPOOL=newrdf-${DATAPOOL}


echo zpool create $NEWDATAPOOL $DATARDF
echo zpool status $NEWDATAPOOL | egrep -v error | grep .
echo zpool list $NEWDATAPOOL




# Define variables
{
export zone_name="metaconv-pz"
export tmp_folder=/net/nfs-infra.isilon/unix/systemstore/temp/${zone_name}
[ ! -d $tmp_folder ] && mkdir $tmp_folder
cd $tmp_folder
who=`who am i | awk '{print $1}'`
export primary_host=morpheus
export secondary_host=niobe
export clustername=`cluster list`
site=$(cmdb host | grep `uname -n` | awk -F';' '{print $5}' | awk '{print $1}')
echo Vmax3>${tmp_folder}/new_storage_array.txt
global_zone_os=`uname -v`

echo "
Current host=       `uname -n`
zone_name=          $zone_name
tmp_folder=         $tmp_folder
who=                $who
primary_host=       $primary_host
secondary_host=     $secondary_host
clustername=        $clustername
site=               $site
new_storage_array=  `cat ${tmp_folder}/new_storage_array.txt`
global_zone_os=     $global_zone_os
"
}


##### variables
export zone_name=<zone_name>
export primary_host=
export secondary_host=
export tmp_folder=/net/nfs-infra.isilon/unix/systemstore/temp/$zone_name
export POOLTOMIGRATE=${zone_name}_<suffix>
export NEWPOOL=newrdf-${POOLTOMIGRATE} 
export OLDPOOL=${POOLTOMIGRATE}_old
export CURDATE=`date "+%Y%m%d"`
export NEWDATE=`date "+%Y%m%d%H%M"`

echo "$NEWPOOL $POOLTOMIGRATE $OLDPOOL $CURDATE $NEWDATE $zone_name $tmp_folder $primary_host $seconday_host"

# Check that the recordsize of the new pool is the same as on the old pool

zfs get -r -s received all $POOLTOMIGRATE
zfs get recordsize $POOLTOMIGRATE $NEWPOOL
zfs get -H recordsize $POOLTOMIGRATE | perl -pe "s:${POOLTOMIGRATE}:${NEWPOOL}:"| awk '{print "zfs set "$2"="$3" "$1}'

zfs get -H recordsize $POOLTOMIGRATE | perl -pe "s:${POOLTOMIGRATE}:${NEWPOOL}:"| awk '{print "zfs set "$2"="$3" "$1}'

zfs get recordsize $POOLTOMIGRATE $NEWPOOL
zfs set recordsize=128K $NEWPOOL
zfs get recordsize $POOLTOMIGRATE $NEWPOOL

====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
# First phase: online
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================

##### snapshot the POOLTOMIGRATE
{
echo zfs snapshot -r ${POOLTOMIGRATE}@${CURDATE} 
echo zfs list -rt snapshot $POOLTOMIGRATE
}

##### send|recieve de POOLTOMIGRATE vers NEWPOOL
{
export TAG=ZFS
echo "logger -p daemon.notice -t $TAG \"POOL: $POOLTOMIGRATE\""
echo "Get details about what data will be transferred by a zfs send before actually sending the data"
echo "zfs send -Rvn ${POOLTOMIGRATE}@${CURDATE}"
echo "Send an incremental data to a target pool"
echo "zfs send -Rv ${POOLTOMIGRATE}@${CURDATE} | zfs receive -Fduv ${NEWPOOL}"
echo "logger -p daemon.notice -t $TAG \"SEND RECEIVE END\""
tail /var/adm/messages | grep $TAG
zfs list -r $NEWPOOL
zfs list -r -t snapshot $NEWPOOL
}

====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
# Second phase: offline
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================

##### disable applications
zlogin ${zone_name}
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} disable 2>/dev/null; done
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
exit


##### save ZFS parameters of POOLTOMIGRATE so they can be re-applied later to NEWPOOL
# check that the tmp_folder variable has been set
echo $tmp_folder && file $tmp_folder
{
for PARAM in mountpoint quota reservation recordsize compression  aclmode aclinherit zoned 
do
  for Filesystem in ` zfs list -Hr $POOLTOMIGRATE | grep -v $CURDATE   | awk '{print $1}'`
  do
    zfs get -H $PARAM $Filesystem | awk '{print "zfs set "$2"="$3" "$1}'
  done
done
} | tee $tmp_folder/PARAM_ZFS_$POOLTOMIGRATE.txt

{
for PARAM in mountpoint quota reservation recordsize compression  aclmode aclinherit zoned 
do
  for Filesystem in ` zfs list -Hr $POOLTOMIGRATE | grep -v $CURDATE   | awk '{print $1}'`
  do
    zfs get -H $PARAM $Filesystem | perl -pe "s:${POOLTOMIGRATE}:${NEWPOOL}:"| awk '{print "zfs set "$2"="$3" "$1}'
  done
done
} | tee $tmp_folder/PARAM_ZFS_$NEWPOOL.txt


################ Suspend the RG

echo clrg suspend ${zone_name}-rg

################ stop zone

{
echo clrs status ${zone_name}-rs
echo clrs disable ${zone_name}-rs
echo clrs status ${zone_name}-rs
# echo zoneadm -z $zone_name halt 
echo zoneadm -z $zone_name list -v
}

# unmount the zpool
# umount /zones/$zone_name


############### PUT CLUSTER RESOURCES OFFLINE


====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
# Create COLD snapshots of the current pool & send incremental backup to the new pool
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================

###############  LAST SNAP


##### variables
export NEWDATE=`date "+%Y%m%d%H%M"`
echo "$zone_name $tmp_folder $NEWPOOL $POOLTOMIGRATE $NEWDATE"

{
echo zfs snapshot -r ${POOLTOMIGRATE}@${NEWDATE}
echo zfs list -rt snapshot $POOLTOMIGRATE
}

{
export TAG=ZFS
echo "logger -p daemon.notice -t $TAG \"POOL: $POOLTOMIGRATE\""
echo "zfs send -Rv -i ${POOLTOMIGRATE}@${CURDATE} ${POOLTOMIGRATE}@${NEWDATE} | zfs receive -Fduv ${NEWPOOL}"
echo "logger -p daemon.notice -t $TAG \"SEND RECEIVE END\""
echo "tail /var/adm/messages | grep $TAG"
}

########### CHECK SIZE
zfs list -rt filesystem $POOLTOMIGRATE $NEWPOOL
zfs list -rt snapshot $POOLTOMIGRATE $NEWPOOL

######################################################################################################################
######################################################################################################################


##### rename the original pool to <original_pool>_old
{
echo zpool export $POOLTOMIGRATE
echo zpool import -N $POOLTOMIGRATE ${OLDPOOL}
echo zpool export ${OLDPOOL}
}

### delete the snapshots on the old pool
{
echo zpool import -N ${OLDPOOL}
echo zfs list -rt snapshot ${OLDPOOL}
echo zfs destroy -r ${OLDPOOL}@${CURDATE}
echo zfs destroy -r ${OLDPOOL}@${NEWDATE}
echo zfs list -rt all  ${OLDPOOL}
echo zpool export ${OLDPOOL}
}

#### change zfs parameters on the new pool

sh ${tmp_folder}/PARAM_ZFS_$POOLTOMIGRATE.txt

### delete the snapshots on the new pool
{
echo zfs list -rt snapshot  ${NEWPOOL}
echo zfs destroy -r ${NEWPOOL}@${CURDATE}
echo zfs destroy -r ${NEWPOOL}@${NEWDATE}
echo zfs list -rt all  ${NEWPOOL}
echo zpool list $NEWPOOL
}

### Suppress the cache files from the old pool
echo /usr/cluster/lib/sc/hasp_util delete_pool_ccr_cachefile -f $POOLTOMIGRATE

### Rename the new pool to the original pool
{
# Rename the new pool to the original pool
echo zpool export $NEWPOOL
# Import the new pool without mounting any filesystem 
echo zpool import $NEWPOOL $POOLTOMIGRATE
echo zfs list -r $POOLTOMIGRATE 
### fix the mountpoints
#### change zfs parameters on the new pool
echo sh $tmp_folder/PARAM_ZFS_$POOLTOMIGRATE.txt
}

### Save the list of pools associated to the zfs resource
zpools=`clrs show -p Zpools ${zone_name}-zfs | nawk -F ":" '/Zpools/ {print $NF}'` && echo $zpools
zpoolslist=`echo $zpools|sed 's: :,:g'` && echo $zpoolslist

### Suppress all pools from the zfs resource
echo clrs set -p Zpools=   ${zone_name}-zfs
echo clrs show -p Zpools ${zone_name}-zfs | nawk -F ":" '/Zpools/ {print $NF}'

### Re-add the zpools to the zfs resource
echo time clrs set -p Zpools=$zpoolslist ${zone_name}-zfs
echo clrs show -p Zpools ${zone_name}-zfs | nawk -F ":" '/Zpools/ {print $NF}'
clrs enable ${zone_name}-zfs


################ Resume the RG

echo clrg resume ${zone_name}-rg

################ restart the zone

{
echo clrs status ${zone_name}-rs
echo clrs enable ${zone_name}-rs
echo clrs status ${zone_name}-rs
echo zoneadm -z $zone_name list -v
}

################ restart the applications

zlogin ${zone_name}
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} enable 2>/dev/null; done
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
exit


------------------------------------------------------------------------------------------------------------------------------
