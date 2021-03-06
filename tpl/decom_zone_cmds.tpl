====================================================================================================================================
In case we only need to shutdown the zone, and decom it after a delay of 30 days:
----------------------------------------------------------------------------------
1. Shutdown the zone and set the RG to the "unmanaged" state.
--------------------------------------------------------------

zone-where <zone_name>
# connect to the zone primary host
zoneadm -z <zone_name> list -v && clrg status <zone_name>-rg
unmanage_zone <zone_name>

------------------------------------------------------------------------------------------------------------------------------------
log:
----

------------------------------------------------------------------------------------------------------------------------------------

2. Put the main ticket in "Planned" and schedule it after 30 days
------------------------------------------------------------------
User Additional Info:
----------------------
The zone <zone_name> has been shut down as requested.
Freeze period before deletion: 30 days

Check box "Planned by current group"
...After: set current date +30 days.

====================================================================================================================================
Remove a zone
--------------
1 Description
--------------
This procedure describes how to remove a Solaris 10 container

2 Prerequisites
----------------
2.1 If the zone rg is in the unmanaged state, then put it back in managed state
--------------------------------------------------------------------------------
zoneadm -z <zone_name> list -v && clrg status <zone_name>-rg
clrg online -M -e -n <primary_host> <zone_name>-rg

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

2.2 on primary source node, disable the applications
-----------------------------------------------------

# Check if the apps are already disabled
check_apps <zone_name>

# get primary host name
primary=`zone-where <zone_name>` && echo $primary
sr $primary

zlogin <zone_name>
os=`uname -r | sed -e 's/^5\./Solaris /'` && echo $os

for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} disable 2>/dev/null; done
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE

3 Instructions
3.1 variables, on both global zones

# define the env variables on both globalzones
-----------------------------------------------

{
export zone_name="<zone_name>"
decom_zone_set_vars <zone_name>
export tmp_folder=/net/nfs-infra.isilon/unix/systemstore/temp/<zone_name>
[ ! -d $tmp_folder ] && mkdir $tmp_folder
cd $tmp_folder
who=`who am i | awk '{print $1}'`
export primary_host=<primary_host>
export secondary_host=<secondary_host>
export clustername=`cluster list`
site=$(cmdb host | grep `uname -n` | awk -F';' '{print $5}' | awk '{print $1}')
global_zone_os=`uname -v`

echo "
Current host=       `uname -n`
zone_name=          <zone_name>
tmp_folder=         $tmp_folder
who=                $who
primary_host=       $primary_host
secondary_host=     $secondary_host
clustername=        $clustername
site=               $site
global_zone_os=     $global_zone_os
"
}

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.5 get OS on primary node
---------------------------

{
os=`zlogin <zone_name> uname -r | sed -e 's/^5\./Solaris /'` && echo $os
clrs list -g <zone_name>-rg | xargs
clrs show -p Zpools <zone_name>-zfs | grep Zpools
ZP=`clrs show -p Zpools <zone_name>-zfs | awk -F":" '/Zpools/ {print $NF}'` && zpool status $ZP | grep -v errors | grep .
cldg show <zone_name> 2>/dev/null | grep -i name | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'
zone_lun_wwn_and_id <zone_name>
}

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.6 get network information, on primary node
---------------------------------------------

{
global_zone_os=`uname -r`
if [ x"$global_zone_os" == x'5.10' ]; then
  zonecfg -z <zone_name> info net | grep address: | awk '{print $2}' | awk -F'/' '{print $1}' | while read ip
    do
      name=`nslookup $ip | grep name | awk '{print $NF}' | sed -e 's/\.$//'`
      echo ${ip}: ${name}
    done > ${tmp_folder}/network_ip.txt
else
  zonecfg -z <zone_name> info anet| grep allowed-address | grep -v configure-allowed-address | awk '{print $2}' | perl -pe 's/,/\n/g' | awk -F'/' '{print $1}' | while read ip
    do
      name=`nslookup $ip | grep name | awk '{print $NF}' | sed -e 's/\.$//'`
      echo ${ip}: ${name}
    done > ${tmp_folder}/network_ip.txt
fi
cat /zones/<zone_name>/root/etc/hosts >${tmp_folder}/network_etc_hosts.txt
cat ${tmp_folder}/network_ip.txt
OPSRVL=`cmdb opsrv | grep <zone_name> | awk -F ";" '{print $1}' | sort -u | xargs` && echo "opsrv list:= $OPSRVL"
}

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.7 get storage information, on both nodes
-------------------------------------------

/home/admin/bin/storage_info.pl -A > ${tmp_folder}/storage_info_`uname -n`.txt && ls -lh ${tmp_folder}/storage_info_`uname -n`.txt

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.8 get zone storage information on primary node
-------------------------------------------------

{
zonecfg -z <zone_name> info dataset | grep name | awk '{print $2}' | awk -F'/' '{print $1}'| sort > ${tmp_folder}/zpools_list.txt
export zpools=`cat ${tmp_folder}/zpools_list.txt| xargs` && echo "\nzpools list: $zpools\n"
zpool status $zpools | egrep -v errors|grep .
}

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

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
}>${tmp_folder}/storage_info_<zone_name>.txt
# cat ${tmp_folder}/storage_info_<zone_name>.txt
cat ${tmp_folder}/storage_hex_lun_id.txt | sort -u | tee ${tmp_folder}/storage_hex_lun_id.txt 
cat ${tmp_folder}/storage_hex_lun_id.txt && wc -l ${tmp_folder}/storage_hex_lun_id.txt

wc -l ${tmp_folder}/storage_info_<zone_name>.txt
cat ${tmp_folder}/storage_info_<zone_name>.txt| awk '{print $1, $9, $(NF-3), $(NF-7), $3, $(NF-8), substr($8,0,10)}'| sed 's/_$//'| sort -u

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.9 get zone storage information on secondary node
---------------------------------------------------

{
for id in `cat ${tmp_folder}/storage_hex_lun_id.txt | sort -u`
do
    grep "$id " ${tmp_folder}/storage_info_`uname -n`.txt | grep `cat ${tmp_folder}/storage_type.txt | sort -u` 
done
} >> ${tmp_folder}/storage_info_<zone_name>.txt
# cat ${tmp_folder}/storage_info_<zone_name>.txt

wc -l ${tmp_folder}/storage_info_<zone_name>.txt
cat ${tmp_folder}/storage_info_<zone_name>.txt| awk '{print $1, $9, $(NF-3), $(NF-7), $3, $(NF-8), substr($8,0,10)}'| sed 's/_$//'| sort -u

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------


3.10 On primary node, get disks WWNs of the zone
-------------------------------------------------

Note:
Make sure that the the positional parameter in awk filter matches the  LUN id 
Sometimes, on VMAX the LUN is on field 28 instead of 18 , but it's more safe to get the 7th field from the end

{
storage_type=`cat ${tmp_folder}/storage_type.txt | grep -v '^$'| sort -u`
case "$storage_type" in
  VMAX)
    cat ${tmp_folder}/storage_info_<zone_name>.txt | awk '{print $(NF-7)}' | sort -u | while read symdevice
    do
      for SID in 000292603453 000292602560
        do 
          symdev show -sid $SID $symdevice| grep 'Device WWN' | awk '{print $4;exit}'
        done
    done
  ;;
  Vmax3)
    cat ${tmp_folder}/storage_info_<zone_name>.txt | awk '{print $(NF-7)}' | sort -u | while read symdevice
    do
       for SID in 000296700060 000296700069
        do 
          symdev show -sid $SID $symdevice| grep 'Device WWN' | awk '{print $4;exit}'
        done
    done
  ;;
  VNX)
    cat ${tmp_folder}/storage_info_<zone_name>.txt | awk '{print $(NF-7)} | sort -u'
  ;;
esac
} | tee ${tmp_folder}/wwn.txt 

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================

3.11 on primary node, stop the zone
------------------------------------

zoneadm -z <zone_name> halt && zoneadm -z <zone_name> list -v

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.12 on primary node, unconfigure the cluster resources for the zone
---------------------------------------------------------------------

{
echo "# <zone_name>-rg"
RS=`clrs list -g <zone_name>-rg| xargs` && echo "# $RS"
echo clrs disable $RS
echo clrs delete $RS
echo clrg offline <zone_name>-rg 
echo clrg delete <zone_name>-rg
}

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.13 on both nodes, unconfigure the zone
-----------------------------------------

zonecfg -z <zone_name> delete -F

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.14 on primary node, destroy zpools
-------------------------------------

{
for pool in `cat ${tmp_folder}/zpools_list.txt`
do
  echo "# Importing pool: $pool"
  echo "zpool import $pool"
  echo "zpool destroy $pool && echo $pool destroyed"
done
}

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.15 on secondary node, remove disk group, if any and cleanup the replicated devices file
-------------------------------------------------------------------------------------------
NOTE:
make sure that the the did's are configured on the secondary node; otherwise go to the primary node

# Cleanup the replicated_devices file by unbinding the binded DID's
#-------------------------------------------------------------------
# If the DG is still present:
-----------------------------
DG=`cldg list | grep <zone_name>` && echo $DG
[ ! -z $DG ] && DGDIDs=`cldg show -v $DG| awk -F":" '/device names/ {print $2}'| xargs | sed 's:/dev/did/rdsk/::g;s:s2::g'` && echo $DGDIDs && cldev show -v $DGDIDs

# Return the replicated DID instance to its prior state of being two separate DID instances.
# check which did's are currently configured for the zone
grep <zone_name> /etc/cluster/ccr/global/replicated_devices
for DID in `echo $DGDIDs| sed 's/d//g'`; do echo "scdidadm -b $DID ; /usr/cluster/bin/scgdevs";done
grep -c <zone_name> /etc/cluster/ccr/global/replicated_devices

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

# If the DG is already removed:
--------------------------------

grep -c <zone_name> /etc/cluster/ccr/global/replicated_devices
DIDLIST=`cat /etc/cluster/ccr/global/replicated_devices| grep <zone_name> | awk '{print $1}'` && echo $DIDLIST
for DID in $DIDLIST; do echo "scdidadm -b $DID ; /usr/cluster/bin/scgdevs";done
grep -c <zone_name> /etc/cluster/ccr/global/replicated_devices

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

# Remove the Cluster Disk Group
--------------------------------
{
echo "cldg list | grep <zone_name>"
echo "cldg show <zone_name> | grep -i name | grep -i name | sed 's:/dev/did/rdsk/::g;s:s2::g'"
echo "cldg offline <zone_name> && cldg delete <zone_name> && cldg list | grep <zone_name>"
echo "cldg list | grep -c <zone_name>"
}

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

Note: 
On old systems, one might have several DG's for one zone 
cldg list | grep <zone_name>

3.16 on both nodes, put the disks offline, one node after the other one (not at same time)
-------------------------------------------------------------------------------------------

# Offline the LUNs
-------------------

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

# If it looks ok, repeat the above command and pipe it to bash

# Unconfigure the removed LUNs
-------------------------------

cleanupluns

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

3.17 remove puppet client configuration
----------------------------------------
Note: ONLY for Solaris 11 (Solaris 10 doesn't use puppet)
For puppet, delete the host from the Foreman GUI : https://foreman/users/login

====================================================================================================================================
# Create ticket for storage: retrieve storage
----------------------------------------------

{
export tmp_folder=/net/nfs-infra.isilon/unix/systemstore/temp/<zone_name>
cat <<EOT
#SMT Template: STORAGE REQUEST - Retrieve unused storage
#SMT Title: Recover storage for <zone_name>
Type of storage (VNX - VMAX - VMAX3 - NAS - eNAS): `cat ${tmp_folder}/storage_type.txt | sort -u`
Impacted hosts: `clnode list | xargs| perl -pe 's/ /, /'`
Masking info (vm, datastore, zone,... name): <zone_name>
LUN WWN and/or ID:
`cat ${tmp_folder}/wwn.txt`
EOT
}

TO: SBA-OP
------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------
Ticket:
------------------------------------------------------------------------------------------------------------------------------------

====================================================================================================================================

3.21 network: free up the zone IP's
------------------------------------

Instructions:
export tmp_folder=/net/nfs-infra.isilon/unix/systemstore/temp/<zone_name>
cat ${tmp_folder}/network_ip.txt
for IP in `awk -F":" '/opsrv/ {print $1}' ${tmp_folder}/network_ip.txt | xargs`; do host $IP;done
OPSRVL=`cat ${tmp_folder}/network_ip.txt | awk '/opsrv/ {print $NF}'| cut -d"." -f1 | xargs` && echo $OPSRVL

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

For the opsrvxx entries, double-check that the opsrv IP @ still matches the configured IP's
Go to https://resop/ip, and complete the template to delete all zone and opsrv entries
Select "Delete" in the Type field
Enter the fqdn in the Record Name field, and click on the "IP" icon, the record value should show up
 
  OR
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
HL="<zone_name> $OPSRVL" && echo $HL

# Hosts IP @
printf "%-12s: " <zone_name> && dig <zone_name>.opoce.cec.eu.int +short

# Create the excel request file (template: OPS-RFC-DNS-delete.xltx)
DATAFILE="/home/claeyje/snet/data.txt"
generate_ip_delete_hostlist_records $HL | tee $DATAFILE && chown claeyje:opunix $DATAFILE && ll $DATAFILE

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $HL

------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------
Ticket: 
------------------------------------------------------------------------------------------------------------------------------------

3.23 change status in CMDB to archived
---------------------------------------

{
who=`who am i | awk '{print $1}'`
echo "The zone <zone_name> has been decommissioned; it can be removed from the CMDB."
} | mailx -s "Update the CMDB: <zone_name>" -r $who -c $who OP-INFRA-OPENSYSTEMS-CHGMGT@publications.europa.eu

