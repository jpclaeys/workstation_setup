Howto migrate storage (vmax to vmax3) for a zpool with srdf disks.
-------------------------------------------------------------------

====================================================================================================================================
# 0. Create the main ticket
====================================================================================================================================
# Create the main ticket, and assign it to myself

# Template: STORAGE REQUEST - Add storage (creation)
# Title: Migrate storage for zone <zone_name> to Vmax3
# Description:
Migrate the old storage VMAX (3453/2560) to new VMAX (060/069) for zone <zone_name>.

Ticket:

====================================================================================================================================
# 1. Define variables
====================================================================================================================================
# Get the primary & secondary nodes:

get_zone_primary_and_secondary_hosts <zone_name>

# Open a session to both primary & secondary hosts

# Define variables
{
export zone_name="<zone_name>"
export tmp_folder=/net/nfs-infra.isilon/unix/systemstore/temp/${zone_name}
[ ! -d $tmp_folder ] && mkdir $tmp_folder
cd $tmp_folder
who=`who am i | awk '{print $1}'`
export primary_host=<primary_host>
export secondary_host=<secondary_host>
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

====================================================================================================================================
# 2. Prepare the storage request
====================================================================================================================================

====================================================================================================================================
# On primary host: get disks size & check if there are any disks already on Vmax3 storage box
====================================================================================================================================
2.1 get zpools luns sizes
------------------------------------------------------------------------------------------------------------------------------------
{
#zpoolslist=`clrs show -p Zpools ${zone_name}-zfs | grep Zpools| awk -F":" '{print $NF}'| xargs` && echo $zpoolslist
zpoolslist=`zonecfg -z $zone_name info dataset| awk '/name:/ {print $NF}'|awk -F"/" '{print $1}'| sort | xargs` && echo $zpoolslist
zpool list $zpoolslist && zpool status $zpoolslist | grep -v errors | grep .
for P in $zpoolslist ; do zpool_LUNs_capacity $P;done
}

2.2 get the disks list
------------------------------------------------------------------------------------------------------------------------------------
# Find the array info (VMAX_3453; VMAX_2560; Vmax3, etc )
# Old storage: MER:  storage_id=000292603453  VMAX_3453; EUFO: storage_id=000292602560  VMAX_2560
# New storage: MER:  storage_id=000296700060  Vmax3_0060; EUFO: storage_id=000296700069  Vmax3_0069

# if the storage_info file doesn't exist, then create it
FILE=${tmp_folder}/storage_info_`uname -n`.txt && /home/admin/bin/storage_info.pl -A > $FILE && ls -lh $FILE

{
echo "#--> Original disks"
zpool status $zpoolslist| egrep -v "$zone_name|name:|mirror|state:"|awk '/ONLINE/ {print $1}'|tee ${tmp_folder}/orig_disks.txt
echo "#--> Original disks info"
for D in `cat ${tmp_folder}/orig_disks.txt|sed 's/s.$//;s/c$/a/'`; do grep $D ${tmp_folder}/storage_info_`uname -n`.txt| awk '{print $9, $(NF-3), $(NF-7), $3, $(NF-8), substr($8,0,10)}'| sed 's/_$//'|sort -u;done
echo "#--> Check if already on Vmax3"
Vmax3DISKS=$(for D in `cat ${tmp_folder}/orig_disks.txt|sed 's/s.$//;s/c$/a/'`; do grep $D ${tmp_folder}/storage_info_`uname -n`.txt| awk '{print $9, $(NF-3), $(NF-7), $3, $(NF-8), substr($8,0,10)}'| sed 's/_$//'|sort -u;done| grep -ic Vmax3) ; echo "Nb of disks on Vmax3: $Vmax3DISKS"
echo "#--> DG disks list"
cldg show $zone_name | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g' 
}

2.3 On both hosts, get the encrypted 24-digit access ID for the host machine or operating node.
------------------------------------------------------------------------------------------------------------------------------------

{
symacl -unique | awk '{print $NF}' > ${tmp_folder}/sym_hostid_`uname -n`.txt
echo "Unique ACL ID for `uname -n`: `cat ${tmp_folder}/sym_hostid_$(uname -n).txt`"
}

2.4 make sure that the personality of the new srdf device group will match the one of the current device group.
------------------------------------------------------------------------------------------------------------------------------------
# Check SRDF personality
#------------------------

# Make sure that RDF1 is "Ready"
symdg_personality_info $zone_name

# Make sure that RDF1 is on MER (VMAX_3453)
symdg_site_info $zone_name

# If RDF1 is on EUFO (VMAX_2560), then put a comment on the excel sheet to ask RDF on EUFO for the new Disk Group.

# Add then following note:

"Note: In the goal to match the current device group, the new device group should be RDF1 Ready at EUFO on <primary_host>"


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
# Template: STORAGE REQUEST: Add Storage (creation)
# Title: Add storage (creation) on $primary_host / $secondary_host for $zone_name

# Description:

Impacted hosts: $primary_host / $secondary_host
Total disk space requested: $totalstorage GB

Note: this storage is aimed to be used for the migration from old VMAX (3453/2560) to new VMAX (060/069).
"

NOTE: Attach excel storage request !!!!

Ticket: 


====================================================================================================================================
# 3. Get old storage infomation
====================================================================================================================================

3.1 get storage information on both nodes
------------------------------------------------------------------------------------------------------------------------------------

/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt


3.2 on primary node, get storage information
------------------------------------------------------------------------------------------------------------------------------------

{
zonecfg -z $zone_name info dataset | grep name: | awk '{print $2}' | awk -F'/' '{print $1}' | sort | xargs | tee ${tmp_folder}/zpool_list.txt
}

# get the device IDs
#--------------------
{
for zpool in `cat ${tmp_folder}/zpool_list.txt`
do
    zpool status $zpool | grep ONLINE | egrep -v "state|mirror|${zpool}" | awk '{print $1}' | while read dev
    do
        /etc/powermt display dev=$dev | grep 'Logical device ID' | awk -F'=' '{print $2}'
    done
done
} | sort -u | tee ${tmp_folder}/device_ids.txt

# get the storage array
#-----------------------
{
for id in `cat ${tmp_folder}/device_ids.txt`
do
    grep " $id " ${tmp_folder}/storage_info_`uname -n`.txt | awk '{print $8}' | awk -F'_' '{print $1}'

done
} | sort -u | tee ${tmp_folder}/storage_array.txt

# get the primary node storage id
#---------------------------------
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
} | tee ${tmp_folder}/primary_node_storage_id.txt

# get the wwn list
#-----------------
{
for id in `cat ${tmp_folder}/device_ids.txt`
do
    export id
    if [ -x /opt/emc/SYMCLI/bin/symdev ]; then
        symdev show -sid `cat ${tmp_folder}/primary_node_storage_id.txt` $id | grep 'Device WWN' | awk '{print $4}'
    else
        /etc/powermt display dev=all | perl -pe 'chomp' | perl -ne 'if(/Logical device ID=($ENV{id})Device WWN=(.{32}?)state=/) {print "$2\n"}'
    fi
done
} | sort -u | tee ${tmp_folder}/wwn.txt

{
printf '%*s\n' 132 ' ' | tr ' ' - && echo "#--> Summary <--#" && printf '%*s\n' 132 ' ' | tr ' ' -
echo "# zpool_list.txt" && cat ${tmp_folder}/zpool_list.txt
echo "\n# zpool status" && zpool status `cat ${tmp_folder}/zpool_list.txt`| grep -v errors| grep .
echo "\n# device_ids.txt" && cat ${tmp_folder}/device_ids.txt
echo "\n# storage_array.txt" && cat ${tmp_folder}/storage_array.txt
echo "\n# primary_node_storage_id.txt" && cat ${tmp_folder}/primary_node_storage_id.txt
echo "\n# wwn.txt" && cat ${tmp_folder}/wwn.txt
printf '%*s\n' 132 ' ' | tr ' ' -
}

3.3 get zone storage information on primary node
------------------------------------------------------------------------------------------------------------------------------------

export zpools=`zonecfg -z $zone_name info dataset | grep name | awk '{print $2}' | awk -F'/' '{print $1}' | sort` && echo $zpools
#zpool status $zpools | egrep -v errors|grep .

{
> ${tmp_folder}/storage_hex_lun_id.txt
> ${tmp_folder}/storage_type.txt
for pool in $zpools
do
  zpool status $pool | grep ONLINE | egrep -v "state:|$pool|mirror" | awk '{print $1}' | sed -e 's/s0$//' -e 's/s2$//' | while read disk
  do
    [ `echo "$disk" | grep -c '^emcpower'` -gt 0 ] && disk=`echo $disk | sed -e 's/c$/a/'`
    line=$(grep "$disk " ${tmp_folder}/storage_info_`uname -n`.txt)
    [ `echo "$line" | egrep -c 'VNX'` -gt 0 ] && export storage_type=VNX
    [ `echo "$line" | egrep -c 'VMAX_2560|VMAX_3453'` -gt 0 ] && export storage_type=VMAX
    [ `echo "$line" | egrep -c 'Vmax3'` -gt 0 ] && export storage_type=Vmax3
    hex_lun_id=`echo "$line" | awk '{print $9}' | uniq`
    grep " $hex_lun_id " ${tmp_folder}/storage_info_`uname -n`.txt | grep $storage_type
    echo "$hex_lun_id" | uniq >> ${tmp_folder}/storage_hex_lun_id.txt
    echo "$storage_type" >> ${tmp_folder}/storage_type.txt
  done
done
}>${tmp_folder}/storage_info_${zone_name}.txt
# cat ${tmp_folder}/storage_info_${zone_name}.txt
cat ${tmp_folder}/storage_hex_lun_id.txt | sort -u | tee ${tmp_folder}/storage_hex_lun_id.txt
cat ${tmp_folder}/storage_hex_lun_id.txt
cat ${tmp_folder}/storage_info_${zone_name}.txt| awk '{print $1, $9, $(NF-3), $(NF-7), $3, $(NF-8), substr($8,0,10)}'| sed 's/_$//'| sort -u

3.4 get zone storage information on secondary node
------------------------------------------------------------------------------------------------------------------------------------

{
for id in `cat ${tmp_folder}/storage_hex_lun_id.txt | sort -u`
do
    grep "$id " ${tmp_folder}/storage_info_`uname -n`.txt | grep `cat ${tmp_folder}/storage_type.txt | sort -u`
done
} >> ${tmp_folder}/storage_info_${zone_name}.txt
# cat ${tmp_folder}/storage_info_${zone_name}.txt
cat ${tmp_folder}/storage_info_${zone_name}.txt| awk '{print $1, $9, $(NF-3), $(NF-7), $3, $(NF-8), substr($8,0,10)}'| sed 's/_$//'| sort -u


3.5 Identify old disks & sizes
------------------------------------------------------------------------------------------------------------------------------------

{
echo "\n#==> Old disks"
zpool status `cat ${tmp_folder}/zpool_list.txt`| grep -i online | egrep -v "$zone_name|state:|mirror"| awk '/ONLINE/ {print $1}' | tee ${tmp_folder}/old_disks.txt

# Create disk lists per pool
#----------------------------
for POOL in `cat ${tmp_folder}/zpool_list.txt`; do echo "\n#==> $POOL" && zpool status $POOL | grep -i online | egrep -v "$zone_name|state:|mirror"| awk '/ONLINE/ {print $1}' | tee ${tmp_folder}/${POOL}_old_disks.txt;done

# Get old disks size
#--------------------
echo "\n#==> Old disks size"
for D in `cat ${tmp_folder}/old_disks.txt`; do
  if [ "${D:0:8}" == "emcpower" ]; then
     D1=$D && D1=`powermt display dev=$D | awk '/pci/ {print $3}'| sed -n 1p`
  else
     D1=`echo $D | sed 's/s.$//;s/$/s0/'`
  fi
  printf "%-24s " $D && luxadm display /dev/rdsk/$D1 | nawk '/capacity/{print " : " $(NF-1)/1024" GB"}'
done | tee ${tmp_folder}/old_disks_size.txt
}

====================================================================================================================================
====================================================================================================================================
# Wait for the Storage Answer:
====================================================================================================================================
====================================================================================================================================

====================================================================================================================================
4. Once the new disks have been created, we can continue
====================================================================================================================================

4.1  Create the new LUNs hex id file
------------------------------------------------------------------------------------------------------------------------------------
# Paste the Excel sheet from storage team

ex.
echo  "0x1\n0x2" | tee ${tmp_folder}/new_storage_hex_lun_id.txt

{
echo "
<paste the disks hexa values>
" | grep . >  ${tmp_folder}/new_storage_hex_lun_id.txt

echo "
<paste the device id's>
" | grep . >  ${tmp_folder}/new_storage_device_ids.txt
}

{
echo "# new_storage_hex_lun_id.txt: " && cat ${tmp_folder}/new_storage_hex_lun_id.txt | xargs
echo "# new_storage_device_ids.txt: " && cat ${tmp_folder}/new_storage_device_ids.txt | xargs
}

4.2 Define the new srdf device group name and check the personality
------------------------------------------------------------------------------------------------------------------------------------
# Define the new srdf device group name
#---------------------------------------
{
symdg list | grep ${zone_name:0:5} | grep ${zone_name:`expr ${#zone_name} - 2`:99}
new_srdf_device_group=$(symdg list | grep ${zone_name:0:5} | grep ${zone_name:`expr ${#zone_name} - 2`:99}| grep -v " $zone_name " | awk '{print $1}') && echo "\n#==> New srdf device group: $new_srdf_device_group\n"

# Check SRDF personality
#------------------------
# make sure that the personality of the new srdf device group matches the one of the current device group. 
# If it's not the case, use the symrdf command to fix it.
# eg. symrdf -g $new_srdf_device_group failover -establish -nop

# Make sure that RDF1 is "Ready"
symdg_personality_info $zone_name
symdg_personality_info $new_srdf_device_group

# Make sure that RDF1 is on MER (Vmax3_0060)
symdg_site_info $zone_name
symdg_site_info $new_srdf_device_group

echo -n "Disks on old DG $zone_name: " && symdg_dev_list $zone_name
echo -n "Disks on new DG $new_srdf_device_group: " && symdg_dev_list $new_srdf_device_group
}

====================================================================================================================================
#  Process  new disks
====================================================================================================================================


4.3 on both nodes, we refresh the storage configuration
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


4.4 get storage configuration on both nodes
------------------------------------------------------------------------------------------------------------------------------------

/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt

4.5 Check that the provided LUNs match the hex value received from the storage
------------------------------------------------------------------------------------------------------------------------------------

egrep -f new_storage_hex_lun_id.txt storage_info_$(uname -n).txt | grep Vmax3 | awk '{print $1, $9, $(NF-3), $(NF-7), $(NF-8), substr($8,0,10)}'| sed 's/_$//' | uniq

# Check that the disks do not belong to any pool
FILTER=`egrep -f new_storage_hex_lun_id.txt storage_info_$(uname -n).txt | grep Vmax3 | awk '{print $(NF-8)}' | sort -u | xargs | sed 's/ /|/g'` && echo $FILTER
[ `zpool status | egrep -c "$FILTER"` -eq 0 ] && echo "OK, disks are free"


4.6 On primary host create the new did list
------------------------------------------------------------------------------------------------------------------------------------

{
for HEXID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do grep " $HEXID " ${tmp_folder}/storage_info_$(uname -n).txt | grep Vmax3 | awk '{print $(NF -3)}' | sort -u;done | tee ${tmp_folder}/new_did_list.txt
}
{
echo "New DID list:  `cat ${tmp_folder}/new_did_list.txt | xargs`"
cldev show -v `cat ${tmp_folder}/new_did_list.txt | xargs`
}

4.7 On secondary host, combine cluster devices
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
for HEXID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do grep " $HEXID " ${tmp_folder}/storage_info_$(uname -n).txt | grep Vmax3 | awk '{print $(NF-7)}' | sort -u;done | tee ${tmp_folder}/new_device_ids.txt

# Combine the the cluster devices
#---------------------------------
[ -f "${tmp_folder}/new_storage_array.txt" ] && cat ${tmp_folder}/new_storage_array.txt || echo Vmax3> ${tmp_folder}/new_storage_array.txt
{
storage_array=`cat ${tmp_folder}/new_storage_array.txt`
for id in `cat ${tmp_folder}/new_device_ids.txt`
do
    did_on_primary=$(grep " $id " ${tmp_folder}/new_storage_array.txt ${tmp_folder}/storage_info_${primary_host}.txt | tail -1 | grep $storage_array | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    did_on_secondary=$(grep " $id " ${tmp_folder}/new_storage_array.txt ${tmp_folder}/storage_info_${secondary_host}.txt | tail -1 | grep $storage_array | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    echo cldev combine -t srdf -g ${zone_name} -d $did_on_primary $did_on_secondary
    echo "didadm -F scsi3 $did_on_primary && cldev show -v $did_on_primary"
done | sort
}

# Remove the old device groups
#------------------------------
{
storage_array=`cat ${tmp_folder}/new_storage_array.txt`
for id in `cat ${tmp_folder}/new_device_ids.txt`
do
    did_on_primary=$(grep " $id " ${tmp_folder}/new_storage_array.txt ${tmp_folder}/storage_info_${primary_host}.txt | grep $storage_array | tail -1 | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
    did_on_secondary=$(grep " $id " ${tmp_folder}/new_storage_array.txt ${tmp_folder}/storage_info_${secondary_host}.txt | grep $storage_array | tail -1 | perl -ne 'print "$1\n" if(/ # (d\d+) # /)')
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


4.8 On primary host get new disks info
------------------------------------------------------------------------------------------------------------------------------------
# Make sure that the new_storage_hex_lun_id.txt file has been created, and populated with the info extracted from the Excel sheet !

FILE=${tmp_folder}/new_storage_hex_lun_id.txt && [ -f "$FILE" ] && cat $FILE || echo "ERROR: file '$FILE' is missing"

{
echo "#--> New disks info"
for ID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do egrep " $ID " ${tmp_folder}/storage_info_$(uname -n).txt | grep Vmax3 | awk '{print $9, $(NF-3), $(NF-7), $(NF-8), substr($8,0,10)}'| sed 's/_$//'| sort -u ; done
echo "#--> New disks list"
for ID in `cat ${tmp_folder}/new_storage_hex_lun_id.txt`; do egrep " $ID " ${tmp_folder}/storage_info_$(uname -n).txt | grep Vmax3 | awk '{print $(NF-8)}'| sort -u ; done | tee ${tmp_folder}/new_disks.txt

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

# Summary
printf '%*s\n' 132 ' ' | tr ' ' - && echo "#--> Summary <--#" && printf '%*s\n' 132 ' ' | tr ' ' -
echo "new_storage_hex_lun_id: " && cat $FILE
zpool status `cat ${tmp_folder}/zpool_list.txt`| egrep -v 'errors|state|config' | grep .
echo  && zpool list `cat ${tmp_folder}/zpool_list.txt`
echo "\n#--> old disks" && cat old_disks_size.txt
echo "\n#--> new disks" && cat new_disks_size.txt
printf '%*s\n' 132 ' ' | tr ' ' -
}

4.9 Format the new disks
------------------------------------------------------------------------------------------------------------------------------------

# Format the new disks
for DEV in `cat ${tmp_folder}/new_disks.txt`; do  echo /home/admin/bin/op_format_s0.sh --emc $DEV;done

# get disk mapping
for DEV in `cat ${tmp_folder}/new_disks.txt` ; do echo "PowerPath Device Info for $DEV" && symmetrix_to_lun $DEV;done

# Check the disk partition table after formatting
for DEV in `cat ${tmp_folder}/new_disks.txt` ; do echo -n "Powerpath Device: $DEV - " && for DISK in `grep $DEV storage_info_$(uname -n).txt| grep Vmax3 | awk '{print $3}'| head -1`;do echo $DISK &&  prtvtoc -h /dev/rdsk/${DISK}s0;done;done

4.10  On the primary host, add new did's to the DiskGroup
------------------------------------------------------------------------------------------------------------------------------------

{
echo "cldg show ${zone_name} | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'"
# for DID in `cat ${tmp_folder}/new_did_list.txt`; do echo cldg add-device -d $DID ${zone_name};done
NEWDIDARG=`cat new_did_list.txt | sort | xargs|sed 's/ /,/g'`
echo cldg add-device -d $NEWDIDARG ${zone_name}
echo "cldg show ${zone_name} | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'"
}

====================================================================================================================================
5. Moving the storage from old to new VMAX using the zpool attach to create a mirror and split
====================================================================================================================================

5.1 define variables:
------------------------------------------------------------------------------------------------------------------------------------

# Summary
{
printf '%*s\n' 132 ' ' | tr ' ' - && echo "#--> Summary <--#" && printf '%*s\n' 132 ' ' | tr ' ' -
zpool status `cat ${tmp_folder}/zpool_list.txt`| egrep -v 'errors|state|config' | grep .
echo  && zpool list `cat ${tmp_folder}/zpool_list.txt`
echo "\n#--> old disks" && cat old_disks_size.txt
echo "\n#--> new disks" && cat new_disks_size.txt
printf '%*s\n' 132 ' ' | tr ' ' -
}

{
# Define the POOLx variables
#-----------------------------
ZPOOLS=`cat ${tmp_folder}/zpool_list.txt` && echo "\n# zpools: $ZPOOLS\n"
idx=0 && for i in $ZPOOLS; do
  ((idx++)) ;  var=POOL${idx} && var_old=${var}_OLD && eval $var=$i && eval $var_old=${i}_old
  printf "%-12s= %s\n" $var ${!var}
  printf "%-12s= %s\n" $var_old ${!var_old}
done
}

{
# define the DISKS variables
#----------------------------
POOL1_OLD_DISKS=(`cat ${tmp_folder}/${POOL1}_old_disks.txt`) && echo "POOL1_OLD_DISKS: ${POOL1_OLD_DISKS[@]}"
POOL1_NEW_DISKS=() && echo "POOL1_NEW_DISKS: ${POOL1_NEW_DISKS[@]}"
[ -n "$POOL2" ] && POOL2_OLD_DISKS=(`cat ${tmp_folder}/${POOL2}_old_disks.txt`) && echo "POOL2_OLD_DISKS: ${POOL2_OLD_DISKS[@]}"
[ -n "$POOL2" ] && POOL2_NEW_DISKS=() && echo "POOL2_NEW_DISKS: ${POOL2_NEW_DISKS[@]}"
}

5.2  Attaching disks (create mirrored disks)
------------------------------------------------------------------------------------------------------------------------------------

{
echo "#--> Attaching disks"
echo zpool status $ZPOOLS

[ "${#POOL1_OLD_DISKS[@]}" -eq "${#POOL1_NEW_DISKS[@]}" ] && for ((i=0;i<${#POOL1_OLD_DISKS[@]};i++)); do echo "zpool attach $POOL1 ${POOL1_OLD_DISKS[$i]} ${POOL1_NEW_DISKS[$i]}";done

[ "${#POOL2_OLD_DISKS[@]}" -eq "${#POOL2_NEW_DISKS[@]}" ] && for ((i=0;i<${#POOL2_OLD_DISKS[@]};i++)); do echo "zpool attach $POOL2 ${POOL2_OLD_DISKS[$i]} ${POOL2_NEW_DISKS[$i]}";done

echo zpool status $ZPOOLS
echo zpool status -x $ZPOOLS
echo zoneadm -z $zone_name list -v
}

# if cldg complains that "The specified device is already in use in some other device group",  then cleanup

for DID in `cat ${tmp_folder}/new_did_list.txt`; do echo "cldg offline dsk/$DID && cldg disable dsk/$DID && cldg delete dsk/$DID";done


5.3 Split zpools in order to keep only the new disks
------------------------------------------------------------------------------------------------------------------------------------

# Dry run
----------
{
echo zpool split -n $POOL1 $POOL1_OLD ${POOL1_OLD_DISKS[@]}
[ -n "$POOL2" ] && echo zpool split -n $POOL2 $POOL2_OLD ${POOL2_OLD_DISKS[@]}
}

# Real command
---------------
{
echo zpool split $POOL1 $POOL1_OLD ${POOL1_OLD_DISKS[@]}
[ -n "$POOL2" ] && echo zpool split $POOL2 $POOL2_OLD ${POOL2_OLD_DISKS[@]}
echo "zpool status $ZPOOLS && zpool list $ZPOOLS && zpool status -xv $ZPOOLS"
}

# Alternative (better way): detach old LUNs
--------------------------------------------
{
echo "#--> Detaching the old disks"
echo zpool status $ZPOOLS
[ "${#POOL1_OLD_DISKS[@]}" ] && for ((i=0;i<${#POOL1_OLD_DISKS[@]};i++)); do echo "zpool detach $POOL1 ${POOL1_OLD_DISKS[$i]}";done
[ "${#POOL2_OLD_DISKS[@]}" ] && for ((i=0;i<${#POOL2_OLD_DISKS[@]};i++)); do echo "zpool detach $POOL2 ${POOL2_OLD_DISKS[$i]}";done
echo "zpool status $ZPOOLS && zpool status -x $ZPOOLS"
echo zoneadm -z $zone_name list -v
}

# Final check
--------------
zpool list $ZPOOLS && zpool status -xv $ZPOOLS
powermt check && cldev status -s fail


5.4 Remove old disks from DiskGroup
------------------------------------------------------------------------------------------------------------------------------------

# Get the storage DIDs
#----------------------
{
for LUN in  `cat ${tmp_folder}/device_ids.txt`; do grep " $LUN " ${tmp_folder}/storage_info_$(uname -n).txt| awk '{print $(NF-3)}'| sort -u;done | tee ${tmp_folder}/did_list.txt

# Remove old disks from DiskGroup
#--------------------------------
echo "cldg show ${zone_name} | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'"
DIDARG=`cat ${tmp_folder}/did_list.txt | xargs|sed 's/ /,/g'` 
echo cldg remove-device -d $DIDARG ${zone_name}
echo "cldg show ${zone_name} | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'"
}

5.5 On the host where the Replicated DID instances were created (usually the secondary host), cleanup the replicated_devices file
------------------------------------------------------------------------------------------------------------------------------------
# Show the entries that need to be removed
#-------------------------------------------
{
FILTER=`cat ${tmp_folder}/did_list.txt|xargs| sed 's/ /|/g;s/d//g'` # && echo $FILTER
awk '{print $1,$2}' /etc/cluster/ccr/global/replicated_devices | egrep "^($FILTER) "
}

# Return the replicated DID instances to their prior state of being two separate DID instances.
#-----------------------------------------------------------------------------------------------
{
echo grep \"${zone_name}:\" /etc/cluster/ccr/global/replicated_devices
for DID in `cat ${tmp_folder}/did_list.txt | sed 's/d//g'`; do echo "scdidadm -b $DID && /usr/cluster/bin/scgdevs";done
echo grep \"${zone_name}:\" /etc/cluster/ccr/global/replicated_devices
}

Note: on the primary host, one need to run "cldev populate" !!!

5.6 Get symdg info before the rename
------------------------------------------------------------------------------------------------------------------------------------
{
date && symdg list | grep ${zone_name:0:5} | grep ${zone_name:`expr ${#zone_name} - 2`:99}
echo -n "\nDevices in DG $zone_name: " && symdg_dev_list $zone_name
echo -n "\nDevices in DG $new_srdf_device_group: " && symdg_dev_list $new_srdf_device_group
}

5.7 Ask storage to rename the DiskGroups
------------------------------------------------------------------------------------------------------------------------------------

rename the old DiskGroup to  old_${zone_name}
rename the new DiskGroup to  ${zone_name}

{
echo "

Please rename the device groups for the zone ${zone_name} in the following way:

${zone_name}  becomes old_${zone_name}

$new_srdf_device_group  becomes ${zone_name}

Note:
Please keep me posted when it's done (jean-pierre.claeys@ext.publications.europa.eu).

Thanks beforehand,
"
} | mailx -s "Device Group renaming for ${zone_name}" -r $who -c $who OPDL-A4-STORAGE-BACKUP@publications.europa.eu

5.8 cleanup old disks
------------------------------------------------------------------------------------------------------------------------------------

{
echo zpool import -N $POOL1_OLD
echo zpool destroy $POOL1_OLD
[ -n "$POOL2_OLD" ] && echo zpool import -N $POOL2_OLD
[ -n "$POOL2_OLD" ] && echo zpool destroy $POOL2_OLD
}

5.9 Final check
------------------------------------------------------------------------------------------------------------------------------------

{
echo "\n#==> Final check for $zone_name"
date && clrg status ${zone_name}-rg
zpool status $ZPOOLS && zpool list $ZPOOLS && zpool status -xv $ZPOOLS      
powermt check && cldev status -s fail
}

====================================================================================================================================
====================================================================================================================================
# Wait for the mail confirmation that the masking has been changed
====================================================================================================================================
====================================================================================================================================


5.10 Check that the masking has been changed for the SRDF device groups
------------------------------------------------------------------------
{
date && symdg list | grep ${zone_name:0:5} | grep ${zone_name:`expr ${#zone_name} - 2`:99}
# Check that the DG contains the new disks
echo -n "\nDevices in DG $zone_name: " && symdg_dev_list $zone_name
}

====================================================================================================================================
6. Return the old disks to the storage team
====================================================================================================================================


6.1 on both nodes, put the disks offline, one node at a time
------------------------------------------------------------------------------------------------------------------------------------

# Offline the LUNs

# on both nodes, get luns info
# for LUN in  `cat ${tmp_folder}/device_ids.txt`; do grep " $LUN " ${tmp_folder}/storage_info_$(uname -n).txt;done
for LUN in  `cat ${tmp_folder}/device_ids.txt`; do grep " $LUN " ${tmp_folder}/storage_info_$(uname -n).txt| awk '{print $1, $9, $(NF-3), $(NF-7), $(NF-8), $3, substr($8,0,10)}'| sed 's/_$//'| sort -u;done

# Note: the script only generates the commands that we have to execute, after double checking.

global_zone_os=`uname -v` && echo "# Global zone OD version: $global_zone_os"

{
for id in `cat ${tmp_folder}/storage_hex_lun_id.txt  | sort -u`
do
  if [ x"$global_zone_os" == x'5.10' -o ! -f /etc/powermt ]; then
    grep " $id " ${tmp_folder}/storage_info_`uname -n`.txt | grep `cat ${tmp_folder}/storage_type.txt| sort -u` | awk '{print "luxadm -e offline /dev/rdsk/"$3"s2"}'
  else
    grep " $id " ${tmp_folder}/storage_info_`uname -n`.txt | grep `cat ${tmp_folder}/storage_type.txt| sort -u` | awk '{print "/home/admin/bin/op_dev_offline_powermt_luxadm.sh "$3}'
  fi
done
} | sh | sort -u

6.2 Unconfigure the removed LUNs
------------------------------------------------------------------------------------------------------------------------------------

cleanupluns


6.3 Open an SMT ticket to SBA-OP to recover the storage
------------------------------------------------------------------------------------------------------------------------------------

{
echo "#SMT Template: STORAGE REQUEST - Retrieve unused storage\n"
echo "#SMT Title: Recover storage for ${zone_name}\n"
echo "Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): `cat ${tmp_folder}/storage_type.txt | sort -u`\n"
echo "Impacted hosts: `clnode list | xargs| perl -pe 's/ /, /'`\n"
echo "Masking info (vm, datastore, zone,... name): $zone_name\n"
echo "LUN WWN and/or ID:
`cat ${tmp_folder}/wwn.txt`"
} | mailx -s "create a ticket for $zone_name with this content" $who

Ticket: 


6.5 last check
------------------------------------------------------------------------------------------------------------------------------------

{
printf '%*s\n' 132 ' ' | tr ' ' -
echo "#==> last check"
printf '%*s\n' 132 ' ' | tr ' ' -
date && zoneadm -z $zone_name list -v && clrg status ${zone_name}-rg
date && zpool status $ZPOOLS && zpool list $ZPOOLS && zpool status -xv $ZPOOLS
printf '%*s\n' 132 ' ' | tr ' ' -
}

====================================================================================================================================
7. Inform Change Management that the storage has been migrated
====================================================================================================================================

{
echo "The storage for the zone $zone_name has been migrated to the new Vmax3"
} | mailx -s "Storage migration to Vmax3 for ${zone_name}" -r $who -c $who OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu


