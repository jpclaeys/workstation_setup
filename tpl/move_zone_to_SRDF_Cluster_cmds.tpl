Solaris 10 : Move zone to SRDF Cluster
======================================
1 Description

This procedure describes how to move a Solaris 10 container from a old cluster to another SRDF cluster. BUT ONLY IF R1 is on MERCIER !! You can switch after
2 Prerequisites
2.1 Before starting, check for old disk group were not cleaned correctly

/home/admin/bin/zone_dgcheck.sh

2.2 If some zpools found and no zone configured. Cleanup each one with

cldg offline ...
cldg delete ...

2.3 And after do this on each node

devfsadm -Cv
cldev populate
cldev clear
cldev status -s fail

3 Instructions
3.1 Setting up variables on the 4 nodes (sources and targets)

su - opsys_ux
. ~claeyje/root_profile 
. /net/opsvc231/applications/homes/claeyje/root_profile 

export zone_name=<zone_name>
primary_source_node=<primarysource>
secondary_source_node=<secondarysource>
primary_target_node=<primarytarget>
secondary_target_node=<secondarytarget>

export tmp_folder=${UNIXSYSTEMSTORE}/temp/${zone_name}
[ ! -d $tmp_folder ] && mkdir $tmp_folder
who=`who am i | awk '{print $1}'`
site=$(/home/admin/bin/getcmdb.sh host | grep `uname -n` | awk -F';' '{print $5}' | awk '{print $1}') && echo $site
mercier_target_node=`/home/admin/bin/getcmdb.sh host | egrep "$primary_target_node|$secondary_target_node" | awk -F";" '/MER/ {print $1}'` && echo $mercier_target_node

start_date=<start_date>
start_hour=<start_time>

cd $tmp_folder

3.2 on both source nodes, get storage information

/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt

3.3 on primary source node, get storage information

zpool status -xv
zonecfg -z $zone_name info dataset | grep name: | awk '{print $2}' | awk -F'/' '{print $1}' | xargs | tee ${tmp_folder}/zpool_list.txt
zpool status `cat ${tmp_folder}/zpool_list.txt`| grep -v errors| grep .

DG=`cldg list | grep $zone_name` && echo $DG
[ ! -z $DG ] && DGDIDs=`cldg show -v $DG| awk -F":" '/device names/ {print $2}'| xargs | sed 's:/dev/did/rdsk/::g;s:s2::g'` && echo $DGDIDs && cldev show -v $DGDIDs

{
for zpool in `cat ${tmp_folder}/zpool_list.txt`
do
    zpool status $zpool | grep ONLINE | egrep -v "state|mirror|${zpool}" | awk '{print $1}' | while read dev
    do
        /etc/powermt display dev=$dev | grep 'Logical device ID' | awk -F'=' '{print $2}'
    done
done
} | sort -u | tee ${tmp_folder}/device_ids.txt

{
for id in `cat /${tmp_folder}/device_ids.txt`
do
    grep " $id " ${tmp_folder}/storage_info_`uname -n`.txt | awk '{print $8}' | awk -F'_' '{print $1}'

done
} | sort -u | tee ${tmp_folder}/storage_array.txt

{
case `cat ${tmp_folder}/storage_array.txt` in
    VMAX)
        [[ $site == 'EUFO' ]] && export storage_id=000292602560
        [[ $site == 'MER' ]]  &&  export storage_id=000292603453
    ;;
    Vmax3)
        [[ $site == 'EUFO' ]] && export storage_id=000296700069
        [[ $site == 'MER' ]]  && export storage_id=000296700060
    ;;
esac
echo $storage_id
} | tee ${tmp_folder}/primary_source_storage_id.txt

{
for id in `cat ${tmp_folder}/device_ids.txt`
do
    export id
    if [ -x /opt/emc/SYMCLI/bin/symdev ]; then
        symdev show -sid `cat ${tmp_folder}/primary_source_storage_id.txt` $id | grep 'Device WWN' | awk '{print $4}'
    else
        /etc/powermt display dev=all | perl -pe 'chomp' | perl -ne 'if(/Logical device ID=($ENV{id})Device WWN=(.{32}?)state=/) {print "$2\n"}'
    fi
done
} | sort -u | tee ${tmp_folder}/wwns.txt

3.4 on primary source node, check the cluster device group number

cldg list | grep $zone_name | wc -l | awk '{print $1}' | tee ${tmp_folder}/cldg_number.txt

3.5 on both target nodes, get storage information

symacl -unique | awk '{print $NF}' | tee ${tmp_folder}/sym_hostid_`uname -n`.txt

3.6 on primary target node, inform to STORAGE team about the planned change

{
dg_number=`cat ${tmp_folder}/cldg_number.txt`
echo "#SMT Title: change masking for ${zone_name} - R1 on MERCIER site / node $mercier_target_node\n
#SMT Template: STORAGE REQUEST - Change masking\n
Masking name (zone/vm): $zone_name
Impacted hosts: ${primary_source_node}, ${secondary_source_node}, ${primary_target_node}, ${secondary_target_node}
Impacted devices (LUN WNN + ID):"
for id in `cat ${tmp_folder}/device_ids.txt`; do echo "$(symdev show -sid `cat ${tmp_folder}/primary_source_storage_id.txt` $id | grep 'Device WWN' | awk '{print $4}');$id" | grep ';'; done | sort -u
echo "\nHello,\n
If it's ok for you, we plan to move the zone ${zone_name} from ${primary_source_node}/${secondary_source_node} to ${primary_target_node}/${secondary_target_node} on ${start_date}  as of ${start_hour} ?
When the zone is down, we will contact you to do the following:
- remove his masking for ${primary_source_node}/${secondary_source_node}"
if [ $dg_number == 0 ]; then
        echo "- change the configuration for his devices to be in SRDF, with R1 on MERCIER site / node $mercier_target_node"
fi
if [ $dg_number -gt 1 -o $dg_number == 0 ]; then
    echo "- create an unique Symmetrix device group named $zone_name for ${primary_target_node}/${secondary_target_node}"
fi
echo "- create his masking for ${primary_target_node}/${secondary_target_node}, with R1 on MERCIER site / node $mercier_target_node\n\nThanks in advance."

} | mailx -s "Open a ticket to SBA-OP for the zone $zone_name with this content" $who

Send a mail to Unix Team
{
echo "Dears,

Please be informed that we plan to move the zone ${zone_name} from ${primary_source_node}/${secondary_source_node} to ${primary_target_node}/${secondary_target_node} on ${start_date} as of ${start_hour}.

Thanks & Best Regards"
} | mailx -s "Zone move: $zone_name" -r $who -c $who,Jean-Claude.VALLET@ext.publications.europa.eu OPDL-INFRA-SYSTEMS@publications.europa.eu

==================================================================================================================================
3.7 if storage team confirms the intervention, we can continue the procedure
==================================================================================================================================
3.8 on primary source node, disable the application, stop the zone and other cluster items

zlogin ${zone_name}
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} disable 2>/dev/null; done
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
exit

clrs disable ${zone_name}-rs
clrs disable ${zone_name}-zfs
clrg offline ${zone_name}-rg
clrg status ${zone_name}-rg
cldg list | grep $zone_name >/dev/null
if [ $? == 0 ]; then
  cldg list | grep ${zone_name} | while read dg
    do
      clrs disable ${zone_name}-srdf
      cldg offline ${dg}
      cldg disable ${dg}
      cldg status ${dg}
    done
fi

# Check the resources status
clrs show -g ${zone_name}-rg | egrep '^Resource:|Enabled'
# Unmanage the RG
clrg unmanage ${zone_name}-rg && clrg status ${zone_name}-rg

3.9 on primary source node, if zpool is in hostbased miroring, cut ZFS mirror, remove eufo devices, keep mercier devices for RW accesses, for the future SRDF group

{
for zpool in `cat ${tmp_folder}/zpool_list.txt`
do
  echo zpool import $zpool
done
}

zpool status `cat ${tmp_folder}/zpool_list.txt` | grep -v error| grep .

{
for zpool in `cat ${tmp_folder}/zpool_list.txt`
do
  if [ `zpool status $zpool | grep -c "mirror"` -gt 0 ]; then    # only split host based mirrored disks
    zpool status $zpool | grep ONLINE | egrep -v "$zpool|state:|mirror" | awk '{print $1}' | while read dev
      do
    disk=`echo $dev | sed -e 's/s2//' -e s'/s0//'`
    grep "$disk " ${tmp_folder}/storage_info_`uname -n`.txt | egrep 'VMAX_2560|Vmax3_0069' >/dev/null
    [[ $? == 0 ]] && echo $dev
      done | xargs echo zpool split $zpool ${zpool}_eufo 
      echo zpool import -N ${zpool}_eufo 
      echo zpool destroy ${zpool}_eufo 
  fi
done
}

zpool status `cat ${tmp_folder}/zpool_list.txt` | grep -v error| grep .

{
for zpool in `cat ${tmp_folder}/zpool_list.txt`
do
  echo zpool export $zpool
done
}
zpool list | grep $zone_name

3.10 on both source nodes, put offline disks

{
for id in `cat ${tmp_folder}/device_ids.txt`
do
    grep $id ${tmp_folder}/storage_info_`uname -n`.txt | awk '{print $3}' | while read disk
    do
        /home/admin/bin/op_dev_offline_powermt_luxadm.sh $disk | sh | sort -u
    done
done
}

devfsadm -Cv && cldev populate && cldev clear && cldev status -s fail

3.11 on primary source node, get zone configuration

zonecfg -z ${zone_name} export -f ${tmp_folder}/${zone_name}.cfg && ls -lh ${tmp_folder}/${zone_name}.cfg 

3.12 on primary cluster node, inform STORAGE team that the zone is stopped, I/O are stopped on storage, and they can change the masking

{
cat <<EOT
Hi,

The ${zone_name} is down; the devices are offline.
Can you please execute the changes previously requested between ${primary_source_node}/${secondary_source_node} and ${primary_target_node}/${secondary_target_node} ?

Thanks in advance.
EOT
} |mailx -s "$change masking for ${zone_name}" $who

===================================================================================================================================
3.13 when masking is changed, we can to continue
===================================================================================================================================

# check before changing the masking

echo | format | tail -3| head -1
powermt display| grep count

# After masking has been changed, on both nodes check the nb of devices

echo | format | tail -3| head -1
powermt display| grep count

# On both target nodes, check the personality of the SRDF group

symdg list | grep ${zone_name}
symdg_dev_list $zone_name
symdg show $zone_name | egrep 'Group (Name:|Type)|RDF State'
powermt display| grep count

3.14 on both target nodes, we refresh the storage configuration

/etc/powermt check
/etc/powermt display

# Check nb of devices 
echo | format | tail -3

# discover the new devices

luxadm -e port
luxadm -e forcelip <FIBER 1>

wait for "CONNECTED" status or check /var/adm/messages and do the same for the other ports

for PORT in `luxadm -e port| nawk '/CONNECTED/ {print $1}'`; do echo "luxadm -e forcelip $PORT; sleep 10;luxadm -e port|grep $PORT";done

# Check nb of devices
echo | format | tail -3

# Create the DID entries
cldev populate

# Note:
# It might happen that it takes some time to get the new DID's 
# check /var/adm/messages
# also echo | format 
tail -1000 /var/adm/messages| grep -i  'changed to OK' | grep "$(date "+%b %e")"
grep "$(date "+%b %e %H")" messages | egrep -i 'did (subpath|instance) .*created|changed to OK'



3.15 on both target nodes we get storage configuration

/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt

3.16 test to import zpools (on MERCIER)

{
for zpool in `cat ${tmp_folder}/zpool_list.txt`
do
    echo zpool import $zpool
done
}
zpool status -xv

zpool status `cat ${tmp_folder}/zpool_list.txt` | grep -v error | grep .

# If the pools can’t be imported, double-check the DID devices. They might be in a bad
# state even if showing up as “Ok” in cldev status

cldev populate 
# (you can also run “scgdevs”, it does more or less the same)

tail /var/adm/messages
# you will see the following lines:
May 31 10:10:12 groucho Cluster.CCR: [ID 108619 daemon.error] /usr/cluster/bin/scgdevs: Cannot find path for a DID device. Check DID configuration.
May 31 10:10:12 groucho Cluster.CCR: [ID 409585 daemon.error] /usr/cluster/bin/scgdevs: Cannot register devices as HA.

# next, clear the errors
cldev refresh
cldev repair
cldev clear

3.17 if zpools are well imported, export them again

{
for zpool in `cat ${tmp_folder}/zpool_list.txt`
do
    echo zpool export $zpool
done
}

3.18 on both target nodes, import zone configuration

zonecfg -z ${zone_name} -f ${tmp_folder}/${zone_name}.cfg && zoneadm -z $zone_name list -v

3.19 on secondary target node, combine cluster devices

# Show existing replicated devices
cat /etc/cluster/ccr/global/replicated_devices | grep -v ^ccr | awk '{print $1}' | sort -k1n | xargs
# Show incorrect entries in replicated devices
cat /etc/cluster/ccr/global/replicated_devices | grep -v ^ccr | awk '{print $1}' | sort -k1n | xargs echo cldev status | sh

{
storage_array=`cat ${tmp_folder}/storage_array.txt`
for id in `cat ${tmp_folder}/device_ids.txt`
do
    did_on_primary=$(grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${primary_target_node}.txt | tail -1 | grep $storage_array | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    did_on_secondary=$(grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${secondary_target_node}.txt | tail -1 | grep $storage_array | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    echo cldev combine -t srdf -g ${zone_name} -d $did_on_primary $did_on_secondary
    echo didadm -F scsi3 $did_on_primary
    echo cldev show $did_on_primary
done
}

# Remove the old disk groups
{
storage_array=`cat ${tmp_folder}/storage_array.txt`
for id in `cat ${tmp_folder}/device_ids.txt`
do
    did_on_primary=$(grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${primary_target_node}.txt | grep $storage_array | tail -1 | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    did_on_secondary=$(grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${secondary_target_node}.txt | grep $storage_array | tail -1 | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    echo cldg offline dsk/${did_on_primary}
    echo cldg offline dsk/${did_on_secondary}
    echo cldg disable dsk/${did_on_primary}
    echo cldg disable dsk/${did_on_secondary}
    echo cldg delete dsk/${did_on_primary}
done
} 

# Check the replicated devices config

grep $zone_name /etc/cluster/ccr/global/replicated_devices

Sometimes, you cannot combine cluster device because the did id was already in use. You have to find it, verify what did device are just not corretly removed and uncombine it with this command :

didadm -b <did device number without d>

3.20 on primary target node, create cluster device group

{
storage_array=`cat ${tmp_folder}/storage_array.txt`
for id in `cat ${tmp_folder}/device_ids.txt`
do
    grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${primary_target_node}.txt | grep $storage_array  | perl -ne 'print "$1\n" if(/ # (d\d+) # /)'
done
} | sort -u >${tmp_folder}/did_list.txt
cat ${tmp_folder}/did_list.txt

{
tmpfile=/var/tmp/hl.txt
/home/admin/bin/getcmdb.sh host |egrep "${primary_target_node}|${secondary_target_node}" >$tmpfile
mercier_target_node=`awk -F";" '/MER/ {print $1}' $tmpfile` && echo "MER:= $mercier_target_node"
eufo_target_node=`awk -F";" '/EUFO/ {print $1}' $tmpfile` && echo "EUFO:= $eufo_target_node"
rm $tmpfile
}

echo cldg create -n ${mercier_target_node},${eufo_target_node} -t rawdisk -d `cat ${tmp_folder}/did_list.txt | xargs | sed -e 's/ /,/g'` $zone_name
cldg show -v $zone_name && cldev show -v `cldg show -v $zone_name| awk -F":" '/device names/ {print $2}'| xargs | sed 's:/dev/did/rdsk/::g;s:s2::g'`

cldg online ${zone_name} && cldg status ${zone_name}
cldg switch -n ${secondary_target_node} ${zone_name} && cldg status ${zone_name}
cldg switch -n ${primary_target_node} ${zone_name} && cldg status ${zone_name}

# Check if there are iopf issues on PowerPath
powermt display dev=all|grep iopf
# if there are devices in "iopf" state, then try to cleanup:
for DEV in `powermt display dev=all|awk '/iopf/ {print $3}'`; do powermt set mode=active class=symm dev=$DEV force;done; powermt display dev=all|grep iopf
# wait a while, and check again to ensure the error doesn't come back
# if ok, save the PowerPath configuration:
powermt save

3.21 on primary target node, create cluster resource group and resources

clrg create ${zone_name}-rg && clrg manage ${zone_name}-rg && clrg status ${zone_name}-rg
clrg set -p Nodelist=${primary_target_node},${secondary_target_node} ${zone_name}-rg
clrg online ${zone_name}-rg && clrg status ${zone_name}-rg
clrg switch -n ${secondary_target_node} ${zone_name}-rg && clrg status ${zone_name}-rg
clrg switch -n ${primary_target_node} ${zone_name}-rg && clrg status ${zone_name}-rg

echo clrs create -g ${zone_name}-rg -t SUNW.HAStoragePlus -p GlobalDevicePaths="${zone_name}" ${zone_name}-srdf
echo clrs create -g ${zone_name}-rg -t SUNW.HAStoragePlus -p zpools=`cat ${tmp_folder}/zpool_list.txt | sed -e 's/ /,/g'` -p Resource_dependencies="${zone_name}-srdf" ${zone_name}-zfs
clrs status ${zone_name}-srdf ${zone_name}-zfs

cat <<- EOT >/opt/SUNWsczone/sczbt/util/sczbt_${zone_name}-rs
RS=${zone_name}-rs
RG=${zone_name}-rg
PARAMETERDIR=/etc/zones
SC_NETWORK=false
SC_LH=
FAILOVER=true
HAS_RS=${zone_name}-zfs
Zonename="${zone_name}"
Zonebrand=`zonecfg -z $zone_name info brand | awk '{print $2}'`
Zonebootopt=""
Milestone="multi-user-server"
Migrationtype="cold"
LXrunlevel="3"
SLrunlevel="3"
Mounts=""
EOT

/opt/SUNWsczone/sczbt/util/sczbt_register -f /opt/SUNWsczone/sczbt/util/sczbt_${zone_name}-rs

# Check the rg configuration
cat /etc/cluster/ccr/global/rgm_rg_${zone_name}-rg


3.22 on primary target node, update zpools

{
for zpool in `cat ${tmp_folder}/zpool_list.txt`
do
    echo zpool upgrade $zpool
    echo zfs upgrade -r $zpool
done
echo zpool status -xv
}

3.23 on one target node, attach the zone, then shutdown it

{
zoneadm -z $zone_name list -v
zone_brand=`zonecfg -z $zone_name info brand | awk '{print $2}'`
if [ "x${zone_brand}" == 'xsolaris' ]; then
    zoneadm -z ${zone_name} attach -u
else
    zoneadm -z ${zone_name} attach
fi
zoneadm -z $zone_name list -v
}

zoneadm -z ${zone_name} boot && zlogin -C ${zone_name}
~~.

{
if [ "x${zone_brand}" == 'xsolaris' ]; then
    zlogin ${zone_name} /usr/bin/hostname ${zone_name}
fi
}

zlogin ${zone_name} init 0 && zlogin -C ${zone_name}
~~.
zoneadm -z $zone_name list -v

3.24 on one target node, enable resource for the zone

clrs enable ${zone_name}-rs && clrs unmonitor ${zone_name}-rs && clrs status ${zone_name}-rs

3.25 on one target node, test a cluster switch

clrg status ${zone_name}-rg && timex clrg switch -n ${secondary_target_node} ${zone_name}-rg && clrg status ${zone_name}-rg

3.26 on one target node, switch the resource group to the primary site

timex clrg switch -n ${primary_target_node} ${zone_name}-rg && clrg status ${zone_name}-rg

3.27 on primary target node, enable application

zlogin ${zone_name}
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} enable 2>/dev/null; done
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE

exit

3.28 on primary source node, unconfigure cluster configuration and disk group

clrs list -g ${zone_name}-rg | xargs echo clrs delete 
clrg delete ${zone_name}-rg 

{
for dg in `cldg status | grep ${zone_name} | awk '{print $1}'`
do
echo cldg offline $dg
echo cldg delete $dg
done
}

3.29 on both source nodes, unconfigure zone

zonecfg -z $zone_name delete -F && zoneadm list -civ | grep -c $zone_name

3.30 On both source nodes - Check the I/O Paths

# The check command will detect a dead path and remove it from the EMC path list.

powermt check

3.31 on primary source node, inform CMDB manager about the change

{
echo "The zone $zone_name has been moved to the cluster ${primary_target_node}/${secondary_target_node}; primrary node is ${primary_target_node}."
} | mailx -s "$zone_name has been moved" -c $who OPDL-INFRA-INT-PROD@publications.europa.eu,OPDL-INFRA-INT-TEST@publications.europa.eu,OP-INFRA-DB@publications.europa.eu,OPDL-INFRA-SYSTEMS@publications.europa.eu

{
echo "The zone $zone_name is now on cluster ${primary_target_node}/${secondary_target_node}; primary node is ${primary_target_node}."
} | mailx -s "update cmdb: ${zone_name}" -c $who OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu

3.32 cleanup LUNs on both source nodes
cleanupluns

