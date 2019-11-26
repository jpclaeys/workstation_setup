
Howto grow a zpool with srdf storage
-------------------------------------

====================================================================================================================================
# 1. Define variables
====================================================================================================================================
# Get the primary & secondary nodes:

get_zone_primary_and_secondary_hosts <zone_name>

# Open a session to both primary & secondary hosts

# Define variables
{
export zone_name="<zone_name>"
export pool_name=<pool_name>
export tmp_folder=${UNIXSYSTEMSTORE}/temp/${zone_name}
[ ! -d $tmp_folder ] && mkdir $tmp_folder
cd $tmp_folder
who=`who am i | awk '{print $1}'`
export primary_host=<primary_host>
export secondary_host=<secondary_host>
export clustername=`cluster list`
site=$(cmdb host | grep `uname -n` | awk -F';' '{print $5}' | awk '{print $1}')
echo Vmax3>${tmp_folder}/storage_array.txt
export storage_array=`cat ${tmp_folder}/storage_array.txt`
global_zone_os=`uname -v`

echo "
Current host=       `uname -n`
zone_name=          $zone_name
pool_name=          $pool_name
tmp_folder=         $tmp_folder
who=                $who
primary_host=       $primary_host
secondary_host=     $secondary_host
clustername=        $clustername
site=               $site
storage_array=      $storage_array
global_zone_os=     $global_zone_os
"
}

====================================================================================================================================
# 2. Prepare the storage request
====================================================================================================================================
====================================================================================================================================
2.1 get zpool luns sizes
------------------------------------------------------------------------------------------------------------------------------------
{
pool_name=<pool_name>
zpool list $pool_name
zpool status $pool_name | grep -v errors | grep .
zpool_LUNs_capacity $pool_name
}

2.2 make sure that the personality of the new srdf device group will match the one of the current device group.
------------------------------------------------------------------------------------------------------------------------------------
# Check SRDF personality
#------------------------

{
# Make sure that RDF1 is "Ready"
symdg_personality_info $zone_name
# Make sure that RDF1 is on MER (VMAX_3453)
symdg_site_info $zone_name
}

2.3 Get the current disks & dids
---------------------------------

{
echo -n "#==> $zone_name devices list: " && symdg_dev_list $zone_name
echo -n "#==> cluster dg did list: " && cldg show -v $zone_name | grep names | cut -d":" -f2 | sed 's:/dev/did/rdsk/::g;s/s2//g' | xargs
}

====================================================================================================================================
--> create an excel sheet:
Zone=$zone_name
Requested=
# Master device
#---------------
Host=
Array=Vmax3_0060
replication=SRDF
# Replicat device
#-----------------
Host=
Array=Vmax3_0069
Note.
Note.
If Replication is "SRDF", do not specify the Replicat host
ex.

            Size            LUN     Master device               Replicat Device
Zone    ACL Policy  Requested   Type    Real    Dec Hexa    Host    Device  Array   Replication Host    Device  Array
$zone_name       EMC_SILVER  <TBD> Go                   $clustername        Vmax3_0060   $replication   $clustername        Vmax3_0069

====================================================================================================================================
Storage request:
-----------------

totalstorage=
echo "
# Template: STORAGE REQUEST: Add Storage (extension)
# Title: Add storage (extension) on $primary_host / $secondary_host for $zone_name

# Description:

Impacted hosts: $primary_host / $secondary_host
Total disk space requested: $totalstorage GB
"

NOTE: Attach excel storage request !!!!

Ticket:

====================================================================================================================================

====================================================================================================================================
====================================================================================================================================
# Wait for the Storage Answer:
====================================================================================================================================
====================================================================================================================================

====================================================================================================================================
3. Once the new disks have been created, we can continue
====================================================================================================================================

3.1  Create the new LUNs hex id file
------------------------------------------------------------------------------------------------------------------------------------
# Paste the Excel sheet from storage team

ex.
echo  "0x<lun hex>" | tee ${tmp_folder}/new_storage_hex_lun_id.txt

3.2 Check that the new disks have been added to the disk group
------------------------------------------------------------------------------------------------------------------------------------
echo -n "#==> $zone_name devices list: " && symdg_dev_list $zone_name

====================================================================================================================================
4.  Process  new disks
====================================================================================================================================


4.1 on both nodes, we refresh the storage configuration
------------------------------------------------------------------------------------------------------------------------------------

/etc/powermt check
/etc/powermt display | grep count

# Check nb of devices
echo | format | tail -3 | head -2

# discover the new devices

wait for "CONNECTED" status or check /var/adm/messages and do the same for the other ports

for PORT in `luxadm -e port| nawk '/CONNECTED/ {print $1}'`; do echo "luxadm -e forcelip $PORT; sleep 10;luxadm -e port|grep $PORT";done

# Check nb of devices
echo | format | tail -3 | head -2

# Create the DID entries
cldev populate

# Note:
# It takes some time to get the new DID instances on the second node
# check /var/adm/messages, and echo | format

tail -1000 /var/adm/messages| grep -i  'changed to OK' | grep "$(date "+%b %e")"
grep "$(date "+%b %e %H")" /var/adm/messages | egrep -i 'did (subpath|instance) .*created|changed to OK'
grep "$(date "+%b %e %H")" /var/adm/messages | egrep -c 'changed to OK'


4.2 get storage configuration on both nodes
------------------------------------------------------------------------------------------------------------------------------------

/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt

4.3 Check that the provided LUNs match the hex value received from the storage
------------------------------------------------------------------------------------------------------------------------------------

egrep -f new_storage_hex_lun_id.txt storage_info_$(uname -n).txt | grep $storage_array | awk '{print $1, $9, $(NF-3), $(NF-7), $(NF-8), substr($8,0,10)}'| sed 's/_$//' | uniq

# Check that the disks do not belong to any pool
FILTER=`egrep -f new_storage_hex_lun_id.txt storage_info_$(uname -n).txt | grep $storage_array | awk '{print $(NF-8)}' | sort -u | xargs | sed 's/ /|/g'` && echo $FILTER
[ `zpool status | egrep -c "$FILTER"` -eq 0 ] && echo "OK, disks are free"

4.4 On primary host create the new did list
------------------------------------------------------------------------------------------------------------------------------------

{
for HEXID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do grep " $HEXID " ${tmp_folder}/storage_info_$(uname -n).txt | grep $storage_array | awk '{print $(NF -3)}' | sort -u;done | tee ${tmp_folder}/new_did_list.txt
}
{
echo "New DID list:  `cat ${tmp_folder}/new_did_list.txt | xargs`"
cldev show -v `cat ${tmp_folder}/new_did_list.txt | xargs`
}

4.4.1 On seconday host create the new did list
------------------------------------------------------------------------------------------------------------------------------------

{
for HEXID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do grep " $HEXID " ${tmp_folder}/storage_info_$(uname -n).txt | grep $storage_array | awk '{print $(NF -3)}' | sort -u;done | tee ${tmp_folder}/secondary_host_new_did_list.txt
}
{
echo "Secondary host New DID list:  `cat ${tmp_folder}/secondary_host_new_did_list.txt | xargs`"
cldev show -v `cat ${tmp_folder}/secondary_host_new_did_list.txt | xargs`
}

4.5 On secondary host, combine cluster devices
------------------------------------------------------------------------------------------------------------------------------------

# Show existing replicated devices
-----------------------------------
cat /etc/cluster/ccr/global/replicated_devices | grep -v ^ccr | awk '{print $1}' | sort -k1n | xargs
# Show incorrect entries in replicated devices
cat /etc/cluster/ccr/global/replicated_devices | grep -v ^ccr | awk '{print $1}' | sort -k1n | xargs echo cldev status | sh

# Check that the new did's are not used in the replicated devices file OR belong to removed zones
--------------------------------------------------------------------------------------------------
{
DIDLIST=`cat ${tmp_folder}/new_did_list.txt` && echo $DIDLIST
FILTER=`echo $DIDLIST| sed 's/d//g;s/ /|/g'` # && echo $FILTER
[ `awk '{print $1,$2}' /etc/cluster/ccr/global/replicated_devices | egrep "^($FILTER) " | wc -l | xargs` -eq 0 ] && echo OK || echo NOK
}

# Create the new devices list
#-----------------------------
for HEXID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do grep " $HEXID " ${tmp_folder}/storage_info_$(uname -n).txt | grep $storage_array | awk '{print $(NF-7)}' | sort -u;done | tee ${tmp_folder}/new_device_ids.txt

# Combine the the cluster devices
#---------------------------------
[ -f "${tmp_folder}/storage_array.txt" ] && cat ${tmp_folder}/storage_array.txt || echo "ERROR: file ${tmp_folder}/storage_array.txt doesn't exist"
{
storage_array=`cat ${tmp_folder}/storage_array.txt`
for id in `cat ${tmp_folder}/new_device_ids.txt`
do
    did_on_primary=$(grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${primary_host}.txt | tail -1 | grep $storage_array | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    did_on_secondary=$(grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${secondary_host}.txt | tail -1 | grep $storage_array | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    echo cldev combine -t srdf -g ${zone_name} -d $did_on_primary $did_on_secondary
    echo "didadm -F scsi3 $did_on_primary && cldev show -v $did_on_primary"
done | sort
}

# Remove the old device groups
#------------------------------
{
storage_array=`cat ${tmp_folder}/storage_array.txt`
for id in `cat ${tmp_folder}/new_device_ids.txt`
do
    did_on_primary=$(grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${primary_host}.txt | grep $storage_array | tail -1 | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    did_on_secondary=$(grep " $id " ${tmp_folder}/storage_array.txt ${tmp_folder}/storage_info_${secondary_host}.txt | grep $storage_array | tail -1 | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    echo "cldg offline dsk/${did_on_primary} && cldg disable dsk/${did_on_primary} && cldg delete dsk/${did_on_primary}"
    echo "cldg offline dsk/${did_on_secondary} && cldg disable dsk/${did_on_secondary} && cldg delete dsk/${did_on_secondary}"
done
}

# Check the replicated devices config
#-------------------------------------

cldg show $zone_name | egrep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'
grep "${zone_name}:" /etc/cluster/ccr/global/replicated_devices

Sometimes, you cannot combine cluster device because the did id was already in use. You have to find it, verify what did device are just not corretly removed and uncombine it with this command :

didadm -b <did device number without d>

4.6 On primary host get new disks info
------------------------------------------------------------------------------------------------------------------------------------
# Make sure that the new_storage_hex_lun_id.txt file has been created, and populated with the info extracted from the Excel sheet !

FILE=${tmp_folder}/new_storage_hex_lun_id.txt && [ -f "$FILE" ] && cat $FILE || echo "ERROR: file '$FILE' is missing"

{
echo "#--> New disks info"
for ID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do egrep " $ID " ${tmp_folder}/storage_info_$(uname -n).txt | grep $storage_array | awk '{print $9, $(NF-3), $(NF-7), $(NF-8), substr($8,0,10)}'| sed 's/_$//'| sort -u ; done
echo "#--> New disks list"
for ID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do egrep " $ID " ${tmp_folder}/storage_info_$(uname -n).txt | grep $storage_array | awk '{print $(NF-8)}'| sort -u ; done | tee ${tmp_folder}/new_disks.txt

echo "#--> New disks size"
# Get new disks size
for D in `cat ${tmp_folder}/new_disks.txt`; do
  if [ "${D:0:8}" == "emcpower" ]; then
     D1=$D && D1=`powermt display dev=$D | awk '/pci/ {print $3}'| sed -n 1p`
  else
     D1=$D
  fi
  printf "%-24s " $D && luxadm display /dev/rdsk/$D1 | nawk '/capacity/{print " : " $(NF-1)/1024" GB"}'
done | tee ${tmp_folder}/new_disks_size.txt
}

4.7 Format the new disks
------------------------------------------------------------------------------------------------------------------------------------

# Format the new disks
for DEV in `cat ${tmp_folder}/new_disks.txt`; do  echo /home/admin/bin/op_format_s0.sh --emc $DEV;done

# get disk mapping
for DEV in `cat ${tmp_folder}/new_disks.txt` ; do echo "PowerPath Device Info for $DEV" && symmetrix_to_lun $DEV;done

# Check the disk partition table after formatting
for DEV in `cat ${tmp_folder}/new_disks.txt` ; do echo -n "Powerpath Device: $DEV - " && for DISK in `grep $DEV storage_info_$(uname -n).txt| grep $storage_array | awk '{print $3}'| head -1`;do echo $DISK &&  prtvtoc -h /dev/rdsk/${DISK}s0;done;done

4.8  On the primary host, add new did's to the DiskGroup
------------------------------------------------------------------------------------------------------------------------------------

{
echo "cldg show ${zone_name} | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'"
# for DID in `cat ${tmp_folder}/new_did_list.txt`; do echo cldg add-device -d $DID ${zone_name};done
NEWDIDARG=`cat new_did_list.txt | sort | xargs|sed 's/ /,/g'`
echo cldg add-device -d $NEWDIDARG ${zone_name}
echo "cldg show ${zone_name} | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'"
}

====================================================================================================================================
5. Add the new disks to the pool
====================================================================================================================================

# Extend the pool
{
newdisk=`grep $(cat ${tmp_folder}/new_storage_hex_lun_id.txt) storage_info_$(uname -n).txt| awk '{print $(NF-8)}'| sort -u` && echo "# $newdisk"
echo "zpool status $pool_name && zpool list $pool_name"
echo "zpool add $pool_name $newdisk"
echo "zpool status $pool_name && zpool list $pool_name"
echo zpool status -xv
}

====================================================================================================================================
6. Resolve the ticket:
====================================================================================================================================

The pool <pool_name> has been extended as requested:

Pool size before extension:


Pool size after extension:

