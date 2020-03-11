
function cleanupluns ()
{
  THISHOST=`uname -n| cut -d"." -f1`
  echo "===> Unconfigure the unusable LUNs on \"$THISHOST\""
  uncfglist=`(cfgadm -al -o show_SCSI_LUN | nawk -F"[ ,]" '/unusable/ {print $1}' | sort -u)`
  if [ ${#uncfglist[0]} -ne 0 ]; then
      cmds=("");
      cmdindex=0;
      for i in ${uncfglist[@]}
      do
          cmds[$cmdindex]="cfgadm -c unconfigure -o unusable_SCSI_LUN $i";
          cmdindex=$((cmdindex + 1))
      done;
      executeCMDs "${cmds[@]}"
      [ $? -ne 0 ] && return 1
      echo "===> Cleanup the /dev & /devices namespaces"
      echo "executing devfsadm -Cv (quiet mode)"
      devfsadm -Cv >/dev/null
      if [ -x "/usr/cluster/bin/cldev" ]; then
        echo "===> Remove all DID references to underlying devices that are no longer attached to the current node."
        echo "executing cldev clear and cldev check ..."
        PATH=$PATH:/usr/cluster/bin/
        echo "===> Remove obsolete device IDs references"
        echo "===> cldev clear"
        cldev clear
        echo "===> cldev check"
        cldev check
        echo "===> cldev populate"
        cldev populate
        echo "===> cldev status -s fail"
        cldev status -s fail  | sed  '1,5d'
      fi
      echo "===> Checking zpool status"
      zpool status -xv
      echo "===> Checking powerpath devices count"
      powermt display | grep count 
      echo "===> Checking powerpath"
      powermt check
      echo "===> Checking powerpath iopf"
      powermt display dev=all|grep iopf
  else
      echo "===> Nothing to cleanup"
      return 1
  fi
}

function cleanup_unavailable_luns ()
{
  THISHOST=`uname -n| cut -d"." -f1`
  echo "===> check powermt"
  /etc/powermt check
  echo "===> Offline unavailable LUNs on \"$THISHOST\""
  UNAVAILABLELUNS=(`echo | format | awk '/avail/ {print $2}'`)
  if [ ${#UNAVAILABLELUNS[0]} -ne 0 ]; then
      cmds=("");
      cmdindex=0;
      for DEV in ${UNAVAILABLELUNS[@]}
      do
          cmds[$cmdindex]="luxadm -e offline /dev/rdsk/${DEV}s0";
          cmdindex=$((cmdindex + 1))
      done;
      executeCMDs "${cmds[@]}"
      [ $? -ne 0 ] && return 1
      echo "===> Cleanup the /dev & /devices namespaces"
      echo "executing devfsadm -Cv (quiet mode)"
      devfsadm -Cv > /dev/null
      if [ -x "/usr/cluster/bin/cldev" ]; then
        echo "===> Remove all DID references to underlying devices that are no longer attached to the current node."
        echo "executing cldev clear and cldev check ..."
        PATH=$PATH:/usr/cluster/bin/
        echo "===> Remove obsolete device IDs references"
        cldev clear
        echo "===> cldev repair"
        cldev repair
        echo "===> cldev refresh"
        cldev refresh
        echo "===> cldev populate"
        cldev populate
        echo "===> cldev check"
        cldev check
        echo "===> cldev status -s fail"
        cldev status -s fail  | sed  '1,5d'
        echo "===> zpool status -xv"
        zpool status -xv
        echo "===> Checking powerpath devices count"
        powermt display | grep count
        echo "===> Checking powerpath"
        powermt check
        echo "===> Checking powerpath iopf"
        powermt display dev=all|grep iopf
      fi
  else
      echo "===> Nothing to cleanup"
      return 1
  fi
}


function lun_wwn_and_id ()
{
local SymmetrixID DEVLIST
[ $# -eq 0 ] && echo "Please enter the zone name " && return 1
SymmetrixID=`symdg list| awk '/'$1'/ {print $4;exit}'` # && echo $SymmetrixID
DEVLIST=`symdg show $1| awk '/\(STD\)/,/RDF Info/'|awk '/DEV/ {print $3}'| sed 's/^0//'` # && echo $DEVLIST
for DEV in $DEVLIST; do WWN=`symdev show -sid $SymmetrixID $DEV | grep 'Device WWN' | awk '{print $4}'| sort -u` && echo "$WWN;$DEV";done
}

function symdg_group_type ()
{
# Return RDF1 or RDF2
[ $# -eq 0 ] && echo "Please enter the zone name " && return 1
symdg list | awk '/'$1'/ {print $1,$2}'
}

function symdg_personality_info ()
{
[ $# -eq 0 ] && echo "Please enter the DG name " && return 1
symdg show $1 | egrep 'Group (Name:|Type)|(RDF|Pair) State'
}

function check_host_symdg_info ()
{
for DG in `cldg list`; do symdg_personality_info $DG;done
}
function symdg_site_info ()
{
[ $# -eq 0 ] && echo "Please enter the disk group name " && return 1
symrdf -g $1 query | head -5
}

function symdg_dev_list ()
{
[ $# -eq 0 ] && echo "Please enter the zone name " && return 1
DEVLIST=`symdg show $1| awk '/\(STD\)/,/RDF Info/'|awk '/DEV/ {print $3}'| sed 's/^0//'` && echo $DEVLIST
}

function powermt_lun_info ()
{
[ $# -eq 0 ] && echo "Please enter the LUN ID" && return 1
powermt display dev=all | ggrep -A10 -B3 ID=$1$
}

function powermt_lun_pseudo ()
{
[ $# -eq 0 ] && echo "Please enter the LUN ID" && return 1
powermt display dev=all | ggrep -B3 ID=$1$ | awk -F"=" '/Pseudo/ {print $NF}'
}

function get_asm_disks_in_zones_config_file ()
{
mypssH "`thosts`"  '(for Z in `/usr/sbin/zoneadm list -c| grep -v global`; do [ "`grep -c match /etc/zones/${Z}.xml`" -gt 0 ] && echo -n "$Z: " &&  grep match /etc/zones/${Z}.xml | awk -F"/" "{print \$(NF-1)}"|sed "s/s.*$//"|sort|xargs ;:;done)'
}

function get_asm_disks_on_all_hosts ()
{
for H in `thosts`; do 
msggreen $H && sre $H '( for DID in `cldev list`; do echo "$DID" &&  dd if=/dev/did/rdsk/${DID}s0 bs=512k count=1 2>/dev/null| strings | grep ORCL;done| ggrep -B1 ORCL | egrep -v "ORCLDISK|--" | xargs)'| sed '1,5d;$d'| sed '$d'
done && echo
}

function get_zpool_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do zpool status $P| grep -v state:|grep ONLINE ;done)';done
}

function get_zpool_srdf_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -eq 0 ] && zpool status $P| grep -v state:|grep ONLINE ;done)';done
}

function get_zpool_one_srdf_disk ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -eq 0 ] && [ `zpool status $P  | egrep -v "state:|NAME|$P"| grep -c ONLINE` -eq 1 ] && zpool status $P| grep -v state:|grep ONLINE ;done)';done
}

function get_zpool_multiple_srdf_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -eq 0 ] && [ `zpool status $P  | egrep -v "state:|NAME|$P"| grep -c ONLINE` -gt 1 ] && zpool status $P| grep -v state:|grep ONLINE ;done)';done
}

function get_zpool_hostbased_mirrored_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && zpool status $P| grep -v state:|grep ONLINE ;done)';done
}

function get_zpool_one_hostbased_mirrored_disk ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -eq 1 ] && zpool status $P| grep -v state:|grep ONLINE ;done)';done
}

function get_zpool_multiple_hostbased_mirrored_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 1 ] && zpool status $P| grep -v state:|grep ONLINE ;done)';done
}

function get_zones_srdf_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -eq 0 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_one_srdf_disk ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -eq 0 ] && [ `zpool status $P  | egrep -v "state:|NAME|$P"| grep -c ONLINE` -eq 1 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_multiple_srdf_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -eq 0 ] && [ `zpool status $P  | egrep -v "state:|NAME|$P"| grep -c ONLINE` -gt 1 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_hostbased_mirrored_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_hostbased_mirrored_disks_prod ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool | egrep "opgtw$|pz"`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_hostbased_mirrored_disks_mer ()
{
for H in `thostsmer`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_hostbased_mirrored_disks_eufo ()
{
for H in `thostseufo`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_hostbased_mirrored_disks_mer ()
{
for H in `thostsmer`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_hostbased_mirrored_disks_eufo ()
{
for H in `thostseufo`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && echo $P | sed 's/-d[ab].*//' ;done| sort -u)';done
}

function get_zones_one_hostbased_mirrored_disk ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -eq 1 ] && echo $P | sed 's/-d[ab].*//' ;done | sort -u)';done
}

function get_zones_multiple_hostbased_mirrored_disks ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 1 ] && echo $P | sed 's/-d[ab].*//' ;done | sort -u)';done
}

function get_zones_hostbased_mirrored_disks_prod ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && echo $P | sed 's/-d[ab].*//' ;done | egrep "opgtw|pz" | sort -u)';done
}

function get_zones_hostbased_mirrored_disks_noprod ()
{
for H in `clhosts`; do msggreen $H && s $H  '(for P in `zpool list -H -o name | grep -v rpool`; do [ `zpool status $P | grep -c mirror` -gt 0 ] && echo $P | sed 's/-d[ab].*//' ;done | egrep -v "opgtw|pz" | sort -u)';done
}

function zpool_LUNs_capacity ()
{
[ $# -eq 0 ] && echo "PLease specify zpool" && return 1
[ `zpool list $1 >/dev/null 2>&1 ; echo $?` -ne 0 ] && echo "Unknown zpool $1" && return 1
echo "LUNs capacity for zpool $1"

if [ `zpool status $1 | grep -c mirror` -eq 0 ]; then
for D in `zpool status $1 | egrep -v "state:|$1"| awk '/ONLINE/ {print $1}'`; do if [ "${D:0:8}" == "emcpower" ]; then D1=$D &&  D1=`powermt display dev=$D | awk '/pci/ {print $3}'| sed -n 1p`;else D1=$D;fi;echo -n $D && luxadm display /dev/rdsk/$D1 | awk '/capacity/{print " : " $(NF-1)/1024" GB"}';done
else
for D in `zpool status $1 | egrep -v "state:|mirror|$1"| awk '/ONLINE/ {print $1}'|awk 'NR%2==1'`; do if [ "${D:0:8}" == "emcpower" ]; then D1=$D &&  D1=`powermt display dev=$D | awk '/pci/ {print $3}'| sed -n 1p`;else D1=$D;fi;echo -n $D && luxadm display /dev/rdsk/$D1 | awk '/capacity/{print " : " $(NF-1)/1024" GB"}';done
fi
}

function get_zpools_total_size ()
{
if [ $# -eq 0 ]; then
zpool list -H -o name,size | grep -v rpool | awk '{print $NF}' | xargs | sed 's/T/*1024/g;s/G//g;s/ /+/g'| bc
else
validatehost $1 || return 1
s $1 get_zpools_total_size
fi
}

function get_zone_zpools_total_size ()
{
[ $# -eq 0 ] && echo "Usage: $FUNCNAME <zonename>" &&  return 1
#echo -n "Total zpools size for zone $1 (GB): "
zonecfg -z $1 info dataset >/dev/null 2>&1 ;RC=$? 
if [ $RC -eq 0 ]; then
  echo -n "`uname -n` $1 (GB) "
  zpool list -H -o name,size `zonecfg -z $1 info dataset| sed 's:/applications::'| awk '/name/ {print $NF}' | xargs`| grep -v rpool | awk '{print $NF}' | xargs | sed 's/T/*1024/g;s/G//g;s/ /+/g' | bc 
fi
}

function get_zones_zpools_total_size ()
{
# Get zpools size for all zones on host
for Z in `zoneadm list | grep -v glo`; do get_zone_zpools_total_size $Z;done
}

function get_all_zones_zpools_total_size ()
{
mypssH "`clhosts`" '(. ./.bashrc ; get_zones_zpools_total_size)'
}

function show_quorum_luns_info ()
{
[ `whoami` != "root" ] && echo "Need to be root to read the disks" && return 1
if [ $# -ne 0 ]; then
  QLUNS="$@"
else
#  clq status -t shared_disk | sed "1,5d"
  QLUNS=`clq status -t shared_disk | awk '/^d/ {print $1}'` # && echo $QLUNS
fi
for L in $QLUNS; do
FULLDEVPATH=`cldev show $L | awk -F":" '/Full Device Path:/ {print $NF;exit}'` # && echo $FULLDEVPATH
DEV=`echo $FULLDEVPATH | awk -F"/" '{print $NF}'`
LINFO=`dd if=${FULLDEVPATH}s0  bs=512 count=1 2> /dev/null | perl -pe 's/\x00.*$/\n/g'` # && echo $LINFO
printf "%-3s: %-40s %s\n" $L $DEV "$LINFO"
done
}

function show_quorum_luns_info_format ()
{
[ `whoami` != "root" ] && echo "Need to be root to read the disks" && return 1
if [ $# -ne 0 ]; then
  QLUNS="$@"
else
#  clq status -t shared_disk | sed "1,5d"
  QLUNS=`clq status -t shared_disk | awk '/^d/ {print $1}'` # && echo $QLUNS
fi
for L in $QLUNS; do
DEV=`cldev show $L | awk -F"/" '/Full Device Path:/ {print $NF;exit}'`
LINFO=`echo | format $DEV inquiry | awk -F "<" '/'$DEV'/ {print $NF}'| sed 's/>//'`
printf "%-3s: %-40s %s\n" $L $DEV "$LINFO"
done
}

function show_quorum_ssd ()
{
# Note: the quorum LUNs are on controller 0
paste -d= <(iostat -x | awk 'NR>2{print $1}') <(iostat -nx | awk 'NR>2{print "/dev/dsk/"$NF}')| grep c0
}

function get_poolname_in_did_using_dd ()
{
local DID
[ $# -eq 0 ] && msg "Usage: $FUNCNAME  <did>" && return 1
DID=`echo $1 | sed 's/d//g'`
dd if=/dev/did/rdsk/d${DID}s0 bs=512 count=100 2> /dev/null | gawk '{gsub(/[[:cntrl:]]/,x)}1' | head -1 | perl -pe 's/(state).*$//g;s/.*name//g;s/\$//g'
}

function get_poolname_in_did_list_using_dd ()
{
local DID
[ `whoami` != "root" ] && echo "Need to be root to read the disks" && return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <did list>" && return 1
DID=`echo $1 | sed 's/d//g'`
for i in $@; do
DID=`echo $i | sed 's/d//g'`
DEV=`cldev show $DID | awk -F":" '/Full/&&/'$(uname -n)'/ {print $NF;exit}'`
echo -n "d$DID: " && get_poolname_in_did_using_dd $DID
done
}

function get_poolname_in_did ()
{
[ `whoami` != "root" ] && echo "Need to be root to read the disks" && return 1
[ $# -ne 1 ] && msg "Usage: $FUNCNAME <did>" && return 1
DID=`echo $1 | sed 's/d//g'`
#DEV=`cldev show $DID | awk -F":" '/Full/&&/'$(uname -n)'/ {print $NF;exit}'| grep -v c[0-3]`
DEV=`cldev show $DID | awk -F":" '/Full/&&/'$(uname -n)'/ {print $NF;exit}'`
[ -z "$DEV" ] && msg "d$DID is not a zool device" && return 1
zdb -l ${DEV}s0 | grep name | xargs 
}

function get_poolname_in_did_list ()
{
[ `whoami` != "root" ] && echo "Need to be root to read the disks" && return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <did list>" && return 1
DID=`echo $1 | sed 's/d//g'`
for i in $@; do
DID=`echo $i | sed 's/d//g'`
#DEV=`cldev show $DID | awk -F":" '/Full/&&/'$(uname -n)'/ {print $NF;exit}'| grep -v c[0-3]`
DEV=`cldev show $DID | awk -F":" '/Full/&&/'$(uname -n)'/ {print $NF;exit}'`
[ -n "$DEV" ] && echo -n "d$DID: " && zdb -l ${DEV}s0 | grep name | xargs | awk '{printf "%s %-24s %s %s\n", $1, $2, $3, $4}'
done
}

function get_poolname_in_all_dids ()
{
get_poolname_in_did_list `cldev list`| grep -v rpool | sort -k3 | awk 'NF==5 {printf "%-5s%-6s%-25s%-10s%s\n", $1, $2, $3, $4, $5}'
}

function get_poolname_in_emc_dev ()
{
[ `whoami` != "root" ] && echo "Need to be root to read the disks" && return 1
[ $# -ne 1 ] && msg "Usage: $FUNCNAME <emc dev name>" && return 1
EMCDEV=$1
DISK=`powermt display dev=$EMCDEV | grep active| tail -1 | awk '{print $3}'`
zdb -l /dev/rdsk/${DISK} | grep -i name
}

function get_poolname_in_emc_dev_list ()
{
[ `whoami` != "root" ] && echo "Need to be root to read the disks" && return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <emc dev name list>" && return 1
EMCDEVLIST="$@"
for EMCDEV in $@;do
DISK=`powermt display dev=$EMCDEV | grep active| tail -1 | awk '{print $3}'`
echo -n "EMCDEV: $EMCDEV DISK: $DISK " && zdb -l /dev/rdsk/${DISK} | grep -i name | xargs
done
}


