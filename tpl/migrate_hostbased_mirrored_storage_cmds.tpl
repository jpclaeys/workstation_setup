Howto migrate storage (vmax to vmax3) for a zpool with host based mirroring
----------------------------------------------------------------------------

# Create the main ticket, and assign it to myself

# Template: STORAGE REQUEST - Add storage (creation)
# Title: migrate storage for zone <zone_name> to Vmax3
# Description:
Mirgrate the old storage VMAX (3453/2560) to new VMAX (060/069) for zone <zone_name>.

Ticket:

====================================================================================================================================


# Get the primary & secondary nodes:
primary_host=`cmdb zone | grep <zone_name> | awk -F";" '/Primary/ {print $7}'` && echo $primary_host
secondary_host=`cmdb zone | grep <zone_name> | awk -F";" '/Secondary/ {print $7}'` && echo $secondary_host

# Open a session to both primary & secondary hosts

# Define variables
{
export zone_name="<zone_name>"
export tmp_folder=${UNIXSYSTEMSTORE}/temp/${zone_name}
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
# On primary host: get disks size & check if there are any disks already on Vmax3 storage box
====================================================================================================================================
# get zpools luns sizes

#zpoolslist=`clrs show -p Zpools ${zone_name}-zfs | grep Zpools| awk -F":" '{print $NF}'| xargs` && echo $zpoolslist
zpoolslist=`zonecfg -z $zone_name info dataset| awk '/name:/ {print $NF}'|awk -F"/" '{print $1}'| sort | xargs` && echo $zpoolslist
zpool list $zpoolslist && zpool status $zpoolslist | grep -v errors | grep .
for P in $zpoolslist ; do zpool_LUNs_capacity $P;done

# Find the array info (VMAX_3453; VMAX_2560; Vmax3, etc )
# Old storage: MER:  storage_id=000292603453  VMAX_3453; EUFO: storage_id=000292602560  VMAX_2560
# New storage: MER:  storage_id=000296700060  Vmax3_0060; EUFO: storage_id=000296700069  Vmax3_0069

# if the storage_info file doesn't exist, then create it
/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt

# get the disks list
{
echo "#--> Original disks"
zpool status $zpoolslist| egrep -v "$zone_name|name:|mirror|state:"|awk '/ONLINE/ {print $1}'|tee ${tmp_folder}/orig_disks.txt
echo "#--> Original disks info"
for D in `cat ${tmp_folder}/orig_disks.txt|sed 's/s.$//;s/c$/a/'`; do grep $D ${tmp_folder}/storage_info_`uname -n`.txt| awk '{print $9, $(NF-3), $(NF-7), $3, $(NF-8), substr($8,0,10)}'| sed 's/_$//'|sort -u;done
echo "#--> Check if already on Vmax3"
Vmax3DISKS=$(for D in `cat ${tmp_folder}/orig_disks.txt|sed 's/s.$//;s/c$/a/'`; do grep $D ${tmp_folder}/storage_info_`uname -n`.txt| awk '{print $9, $(NF-3), $(NF-7), $(NF-8), substr($8,0,10)}'| sed 's/_$//'|sort -u;done| grep -ic Vmax3) ; echo "Nb of disks on Vmax3: $Vmax3DISKS"
}


====================================================================================================================================
--> create an excel sheet:
Zone=$zone_name
Requested=
# Master device
#---------------
Host=
Array=Vmax3_0060
Replication=HostBased
# Replicat device
#-----------------
Host=
Array=Vmax3_0069
ex.

            Size            LUN     Master device               Replicat Device     
Zone    ACL Policy  Requested   Type    Real    Dec Hexa    Host    Device  Array   Replication Host    Device  Array
$zone_name       EMC_SILVER  <TBD> Go                   $clustername        Vmax3_0060   HostBased   $clustername        Vmax3_0069


Storage request:
-----------------
totalstorage=

echo "
Template: STORAGE REQUEST: Add Storage (creation)
Title: Add storage (creation) on $primary_host / $secondary_host for $zone_name

Description:

Impacted hosts: $primary_host / $secondary_host
Total disk space requested: $totalstorage GB

Note: this storage is aimed to be used for the migration from old VMAX (3453/2560) to new VMAX (060/069).
"

Ticket: 

====================================================================================================================================
3.2 get storage information on both nodes
====================================================================================================================================

/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt

3.3 on primary node, get storage information

zpool status -xv
zonecfg -z $zone_name info dataset | grep name: | awk '{print $2}' | awk -F'/' '{print $1}' | sort | xargs | tee ${tmp_folder}/zpool_list.txt
zpool status `cat ${tmp_folder}/zpool_list.txt`| grep -v errors| grep .

# get the device IDs
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
{
for id in `cat /${tmp_folder}/device_ids.txt`
do
    grep " $id " ${tmp_folder}/storage_info_`uname -n`.txt | awk '{print $8}' | awk -F'_' '{print $1}'

done
} | sort -u | tee ${tmp_folder}/storage_array.txt

# get the primary node storage id
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
printf '%*s\n' 132 ' ' | tr ' ' -
echo "\n#--> Summary <--#\n"
echo "# zpool_list.txt" && cat ${tmp_folder}/zpool_list.txt
echo "\n# zpool status" && zpool status `cat ${tmp_folder}/zpool_list.txt`| grep -v errors| grep .
echo "\n# device_ids.txt" && cat ${tmp_folder}/device_ids.txt
echo "\n# storage_array.txt" && cat ${tmp_folder}/storage_array.txt
echo "\n# primary_node_storage_id.txt" && cat ${tmp_folder}/primary_node_storage_id.txt
echo "\n# wwn.txt" && cat ${tmp_folder}/wwn.txt
printf '%*s\n' 132 ' ' | tr ' ' -
}


3.8 get zone storage information on primary node

export zpools=`zonecfg -z $zone_name info dataset | grep name | awk '{print $2}' | awk -F'/' '{print $1}' | sort` && echo $zpools

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
#cat ${tmp_folder}/storage_info_${zone_name}.txt
cat ${tmp_folder}/storage_hex_lun_id.txt | sort -u | tee ${tmp_folder}/storage_hex_lun_id.txt
cat ${tmp_folder}/storage_hex_lun_id.txt

cat ${tmp_folder}/storage_info_${zone_name}.txt| awk '{print $1, $9, $(NF-3), $(NF-7), $(NF-8), substr($8,0,10)}'| sed 's/_$//'| sort -u

3.9 get zone storage information on secondary node

{
for id in `cat ${tmp_folder}/storage_hex_lun_id.txt | sort -u`
do
    grep "$id " ${tmp_folder}/storage_info_`uname -n`.txt | grep `cat ${tmp_folder}/storage_type.txt | sort -u`
done
} >> ${tmp_folder}/storage_info_${zone_name}.txt
#cat ${tmp_folder}/storage_info_${zone_name}.txt

cat ${tmp_folder}/storage_info_${zone_name}.txt| awk '{print $1, $9, $(NF-3), $(NF-7), $(NF-8), substr($8,0,10)}'| sed 's/_$//'| sort -u

# Identify mercier and eufo old disks

{
echo "\nAll disks"
zpool status `cat ${tmp_folder}/zpool_list.txt`| grep -i online | egrep -v "$zone_name|state:|mirror"| awk '/ONLINE/ {print $1}' | tee ${tmp_folder}/old_disks.txt
VMAX_MER=VMAX_3453 && VMAX_EUFO=VMAX_2560

echo "\nMER disks"
for DISK in `cat ${tmp_folder}/old_disks.txt | sed 's/s.$//;s/c$/a/'`; do
 if [ ${DISK:0:1} == "e" ] ; then
   grep " $DISK " ${tmp_folder}/storage_info_`uname -n`.txt|grep $VMAX_MER | awk '{print $(NF-8)}' | sort -u
 else
   grep " $DISK " ${tmp_folder}/storage_info_`uname -n`.txt|grep $VMAX_MER | awk '{print $3}'|sed 's/s.$//;s/$/s0/' | sort -u
 fi
done| tee ${tmp_folder}/old_disks_mer.txt

echo "\nEUFO disks"
for DISK in `cat ${tmp_folder}/old_disks.txt | sed 's/s.$//;s/c$/a/'`; do
 if [ ${DISK:0:1} == "e" ] ; then
   grep " $DISK " ${tmp_folder}/storage_info_`uname -n`.txt|grep $VMAX_EUFO | awk '{print $(NF-8)}' | sort -u
 else
   grep " $DISK " ${tmp_folder}/storage_info_`uname -n`.txt|grep $VMAX_EUFO | awk '{print $3}' | sed 's/s.$//;s/$/s0/' | sort -u
 fi
done| tee ${tmp_folder}/old_disks_eufo.txt
}

{
echo "#--> Old disks size on MER"
# Get old disks size
for D in `cat ${tmp_folder}/old_disks_mer.txt`; do
  if [ "${D:0:8}" == "emcpower" ]; then
     D1=$D && D1=`powermt display dev=$D | awk '/pci/ {print $3}'| sed -n 1p`
  else
     D1=`echo $D | sed 's/s.$//;s/$/s0/'`
  fi
  echo -n $D && luxadm display /dev/rdsk/$D1 | nawk '/capacity/{print " : " $(NF-1)/1024" GB"}'
done | tee ${tmp_folder}/old_disks_mer_size.txt

echo "\n#--> Old disks size on EUFO"
for D in `cat ${tmp_folder}/old_disks_eufo.txt`; do
  if [ "${D:0:8}" == "emcpower" ]; then
     D1=$D && D1=`powermt display dev=$D | awk '/pci/ {print $3}'| sed -n 1p`
  else
     D1=`echo $D | sed 's/s.$//;s/$/s0/'`
  fi
  echo -n $D && luxadm display /dev/rdsk/$D1 | nawk '/capacity/{print " : " $(NF-1)/1024" GB"}'
done | tee ${tmp_folder}/old_disks_eufo_size.txt
}

====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
Wait for storage 
====================================================================================================================================
====================================================================================================================================
====================================================================================================================================
------------------------------------------------------------------------------------------------------------------------------------
# Paste the Excel sheet received from the storage:



#=====>>>>> Create the new LUNs hex id file
ex.
echo  "0x1\n0x2" | tee ${tmp_folder}/new_dev_hex_id.txt


------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================
3.  Get new disks
====================================================================================================================================


3.14 on both nodes, we refresh the storage configuration

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
# It might happen that it takes some time to get the new DID's
# check /var/adm/messages
# also echo | format
tail -1000 /var/adm/messages| grep -i  'changed to OK' | grep "$(date "+%b %e")"
grep "$(date "+%b %e %H")" /var/adm/messages | egrep -i 'did (subpath|instance) .*created|changed to OK'



3.15 get storage configuration on both nodes

/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt

====================================================================================================================================
# get new device info
====================================================================================================================================
# Make sure that the new_dev_hex_id.txt file has been created, and populated with the info extracted from the Excel sheet !

FILE=${tmp_folder}/new_dev_hex_id.txt && [ -f "$FILE" ] && cat $FILE || echo "ERROR: file '$FILE' is missing"

{
Vmax3_MER=Vmax3_0060 && Vmax3_EUFO=Vmax3_0069
echo "#--> New disks info"
for ID in `cat ${tmp_folder}/new_dev_hex_id.txt`; do egrep " $ID " ${tmp_folder}/storage_info_$(uname -n).txt | grep Vmax3 |  awk '{print $(NF-3), $9, $(NF-7),$(NF-8),substr($8,0,10)}'| sort -u ; done
echo "#--> New disks"
for ID in `cat ${tmp_folder}/new_dev_hex_id.txt`; do egrep " $ID " ${tmp_folder}/storage_info_$(uname -n).txt | grep Vmax3 |  awk '{print $(NF-8)}'| sort -u ; done | tee ${tmp_folder}/new_disks.txt
echo "#--> New disks on MER"
for ID in `cat ${tmp_folder}/new_dev_hex_id.txt`; do egrep " $ID " ${tmp_folder}/storage_info_$(uname -n).txt | grep $Vmax3_MER |  awk '{print $(NF-8)}'| sort -u ; done | tee ${tmp_folder}/new_disks_mer.txt
echo "#--> New disks on EUFO"
for ID in `cat ${tmp_folder}/new_dev_hex_id.txt`; do egrep " $ID " ${tmp_folder}/storage_info_$(uname -n).txt | grep $Vmax3_EUFO |  awk '{print $(NF-8)}'| sort -u ; done | tee ${tmp_folder}/new_disks_eufo.txt


echo "#--> New disks size on MER"
# Get new disks size
for D in `cat ${tmp_folder}/new_disks_mer.txt`; do
  if [ "${D:0:8}" == "emcpower" ]; then
     D1=$D && D1=`powermt display dev=$D | awk '/pci/ {print $3}'| sed -n 1p`
  else
     D1=$D
  fi
  echo -n $D && luxadm display /dev/rdsk/$D1 | nawk '/capacity/{print " : " $(NF-1)/1024" GB"}'
done | tee ${tmp_folder}/new_disks_mer_size.txt

echo "#--> New disks size on EUFO"
for D in `cat ${tmp_folder}/new_disks_eufo.txt`; do
  if [ "${D:0:8}" == "emcpower" ]; then
     D1=$D && D1=`powermt display dev=$D | awk '/pci/ {print $3}'| sed -n 1p`
  else
     D1=$D
  fi
  echo -n $D && luxadm display /dev/rdsk/$D1 | nawk '/capacity/{print " : " $(NF-1)/1024" GB"}'
done | tee ${tmp_folder}/new_disks_eufo_size.txt

# Summary

echo "\n#--> Summary <--#\n"
zpool status `cat ${tmp_folder}/zpool_list.txt`| egrep -v 'errors|state|config' | grep .
zpool list `cat ${tmp_folder}/zpool_list.txt`
echo "#--> MER old disks" && cat old_disks_mer_size.txt 
echo "#--> EUFO old  disks" && cat old_disks_eufo_size.txt 
echo "#--> MER new disks" && cat new_disks_mer_size.txt
echo "#--> EUFO new  disks" && cat new_disks_eufo_size.txt
}

====================================================================================================================================
4. replace the LUNs on one site at a time
====================================================================================================================================
# Make sure that the replace on first site is finished prior to start the second site !

{
# Define the POOLx variables
#-----------------------------
ZPOOLS=`cat ${tmp_folder}/zpool_list.txt` && echo "#==> ZPOOLS: $ZPOOLS"
idx=0 && for i in $ZPOOLS; do
  ((idx++)) ;  var=POOL${idx} && var_old=${var}_OLD && eval $var=$i && eval $var_old=${i}_old
  printf "%-12s= %s\n" $var ${!var}
  printf "%-12s= %s\n" $var_old ${!var_old}
done
}

{
# define the DISKS variables
#----------------------------
POOL1_OLD_DISKS_MER=() && echo "POOL1_OLD_DISKS_MER: ${POOL1_OLD_DISKS_MER[@]}"
POOL1_OLD_DISKS_EUFO=() && echo "POOL1_OLD_DISKS_EUFO: ${POOL1_OLD_DISKS_EUFO[@]}"
POOL1_NEW_DISKS_MER=() && echo "POOL1_NEW_DISKS_MER: ${POOL1_NEW_DISKS_MER[@]}"
POOL1_NEW_DISKS_EUFO=() && echo "POOL1_NEW_DISKS_EUFO: ${POOL1_NEW_DISKS_EUFO[@]}"

if [ -n "$POOL2" ]; then
  POOL2_OLD_DISKS_MER=() && echo "POOL2_OLD_DISKS_MER: ${POOL2_OLD_DISKS_MER[@]}"
  POOL2_OLD_DISKS_EUFO=() && echo "POOL2_OLD_DISKS_EUFO: ${POOL2_OLD_DISKS_EUFO[@]}"
  POOL2_NEW_DISKS_MER=() && echo "POOL2_NEW_DISKS_MER: ${POOL2_NEW_DISKS_MER[@]}"
  POOL2_NEW_DISKS_EUFO=() && echo "POOL2_NEW_DISKS_EUFO: ${POOL2_NEW_DISKS_EUFO[@]}"
fi
}

# Format the new disks
#----------------------

for DEV in `cat ${tmp_folder}/new_disks.txt`; do  echo /home/admin/bin/op_format_s0.sh --emc $DEV;done

{
# Replace disks on MER
#----------------------
echo "#--> Replacing disks on MER"
echo zpool status $ZPOOLS
[ "${#POOL1_OLD_DISKS_MER[@]}" -eq "${#POOL1_NEW_DISKS_MER[@]}" ] && for ((i=0;i<${#POOL1_OLD_DISKS_MER[@]};i++)); do echo "zpool replace $POOL1 ${POOL1_OLD_DISKS_MER[$i]} ${POOL1_NEW_DISKS_MER[$i]}";done
[ "${#POOL2_OLD_DISKS_MER[@]}" -eq "${#POOL2_NEW_DISKS_MER[@]}" ] && for ((i=0;i<${#POOL2_OLD_DISKS_MER[@]};i++)); do echo "zpool replace $POOL2 ${POOL2_OLD_DISKS_MER[$i]} ${POOL2_NEW_DISKS_MER[$i]}";done
echo zpool status $ZPOOLS
}

{
# Replace disks on EUFO
#-----------------------
echo "#--> Replacing disks on EUFO"
echo zpool status $ZPOOLS
[ "${#POOL1_OLD_DISKS_EUFO[@]}" -eq "${#POOL1_NEW_DISKS_EUFO[@]}" ] && for ((i=0;i<${#POOL1_OLD_DISKS_EUFO[@]};i++)); do echo "zpool replace $POOL1 ${POOL1_OLD_DISKS_EUFO[$i]} ${POOL1_NEW_DISKS_EUFO[$i]}";done
[ "${#POOL2_OLD_DISKS_EUFO[@]}" -eq "${#POOL2_NEW_DISKS_EUFO[@]}" ] && for ((i=0;i<${#POOL2_OLD_DISKS_EUFO[@]};i++)); do echo "zpool replace $POOL2 ${POOL2_OLD_DISKS_EUFO[$i]} ${POOL2_NEW_DISKS_EUFO[$i]}";done
echo zpool status $ZPOOLS
}


zpool list $ZPOOLS && zpool status -xv $ZPOOLS
powermt check && cldev status -s fail

====================================================================================================================================
# Return the old disks to the storage team
====================================================================================================================================

# Get the storage hex lun ids
for LUN in  `cat ${tmp_folder}/device_ids.txt`; do grep " $LUN " ${tmp_folder}/storage_info_$(uname -n).txt| awk '{print $9}'| sort -u;done | tee ${tmp_folder}/storage_hex_lun_id.txt


3.16 on both nodes, put the disks offline, one node after the other one (not at same time)

# Offline the LUNs

# on both nodes, get luns info
for LUN in  `cat ${tmp_folder}/device_ids.txt`; do grep " $LUN " ${tmp_folder}/storage_info_$(uname -n).txt| awk '{print $1, $9, $(NF-3), $(NF-7), $(NF-8), $3, substr($8,0,10)}'| sed 's/_$//'| sort -u;done

# Note: the script only generates the commands that we have to execute, after double checking.

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

# Unconfigure the removed LUNs

cleanupluns


3.19 Open an SMT ticket to SBA-OP to recover the storage

{
echo "#SMT Title: recover storage for ${zone_name}"
echo "#SMT Template: STORAGE REQUEST - Retrieve unused storage"
echo
echo "Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): `cat ${tmp_folder}/storage_type.txt | sort -u`"
echo "Impacted hosts: `clnode list | xargs| perl -pe 's/ /, /'`"
echo "Masking info (vm, datastore, zone,... name): $zone_name"
echo "LUN WWN and/or ID:
`cat ${tmp_folder}/wwn.txt`"
echo; echo Merci
} | mailx -s "create a ticket for $zone_name with this content" $who

Ticket: 

3.20 Inform Change Management  that the storage has been migrated

{
echo "The storage for the zone $zone_name has been migrated to the new Vmax3"
} | mailx -s "Storage migration to Vmax3 for ${zone_name}" -r $who -c $who OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu

