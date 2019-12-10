function check_zones_cmdb_against_host ()
{
# comm examples:
#       comm -12 file1 file2
#              Print only lines present in both file1 and file2.
#
#       comm -3 file1 file2
#              Print lines in file1 not in file2, and vice versa.
#
# Check zones differences between cmdb and zoneadm list on the global zones

TIMESTAMP=`date "+%Y%m%d%H%M%S"`
DIR=/var/tmp
FILE1=${DIR}/zl_real_$TIMESTAMP.log
FILE2=${DIR}/zl_cmdb_$TIMESTAMP.log
echo "a Host info" > $FILE1
echo "a Cmdb info" > $FILE2

mypssH "`t5hosts`" '(/usr/sbin/zoneadm list| egrep -v "NAME|glob")'| grep -v '\['| sort >> $FILE1
cmdb zone | grep -v ^ZONE | awk -F";" '{print $1}' | sort -u >> $FILE2
comm -3 $FILE1 $FILE2 --output-delimiter="		"
rm $FILE1 $FILE2
}


function check_if_all_zones_are_running_on_their_primary_host ()
{
for Z in `clhosts`; do msggreen $Z && s $Z check_if_zones_are_running_on_their_primary_host;done
}

function check_if_zones_are_running_on_their_primary_host ()
{
ZNOK=
for Z in `zones_secondary_on_current_node`; do
[ `zoneadm -z $Z list -v | grep -c running` -eq 1 ] && ZNOK+=" $Z"
done
[ ! -z "$ZNOK" ] && msg "Following zones are not running on their primary host `uname -n`" && echo $ZNOK
}

function check_iopf ()
{
for H in `clhosts`; do
  msggreen "$H" && sre $H powermt display dev=all|\grep iopf
done
}

function check_powerpath ()
{
for H in `clhosts`; do
  msggreen "$H" && sre $H powermt check
done
}

function check_powerpath_device_count ()
{
for H in `clhosts`; do
  msggreen "$H" && sre $H powermt display |\grep "count="
done
}

function check_cldev_status ()
{
for H in `clhosts`; do
  msggreen "$H" && sre $H cldev status -s fail | sed '1,5d'
done
}

function check_host_based_mirrored_zones ()
{
for H in `clhosts`; do
msggreen $H && s $H zpool status | grep -B1 mirror-0 | egrep -v 'rpool|mirror|--'| awk '{print $1}'| sed 's/-d[ab].*//'| sort -u | xargs
done
}

function check_ldm ()
{
for H in `primary_domains`; do 
msggreen $H && sre $H ldm list
done
}

function check_fmadm ()
{
for H in `primary_domains`; do 
# msggreen $H && sre $H fmadm faulty -s
msggreen $H && sre $H '(fmadm faulty | grep -A4 EVENT)'
done
}

function check_clq_quorum_disks ()
{
# for H in `clhosts`; do
#  msggreen "$H" && sre $H clq status -t shared_disk | sed '1,5d'
#  msggreen "$H" && s $H clq status -t shared_disk | sed '1,5d'
# done
mypssH "`clhosts`" '(/usr/cluster/bin/clq status -t shared_disk | sed "1,5d")'
}

function check_clq_node ()
{
mypssH "`clhosts`" '(/usr/cluster/bin/clq status -t node | sed "1,5d")'
}

function check_clq ()
{
mypssH "`clhosts`" '(/usr/cluster/bin/clq status)'
}

function check_clq_summary ()
{
mypssH "`clhosts`" '(/usr/cluster/bin/clq status | sed -n "4,8p")'
}

function check_clinterconnect ()
{
for H in `clhosts`; do
  msggreen "$H" && sre $H clintr status
done
}

function check_zpools ()
{
mypssH "`clhosts`" /usr/sbin/zpool status -x
}

function check_apps_nok ()
{
mypssH "`zoneslistall`" '(for application in `ls /applications | grep -v wood | sed "s/\///g"`;do /applications/${application}/users/system/init.d/${application} status 2> /dev/null;done | egrep -v "STATE|online";:)'
}

function check_apps_prod_nok ()
{
mypssH "`zoneslistprod`" '(for application in `ls /applications | grep -v wood | sed "s/\///g"`;do /applications/${application}/users/system/init.d/${application} status 2> /dev/null;done | egrep -v "STATE|online";:)'
}

function check_apps_noprod_nok ()
{
zoneslistnoprod > /dev/null
mypssH "`zoneslistnoprod`" '(for application in `ls /applications | grep -v wood | sed "s/\///g"`;do /applications/${application}/users/system/init.d/${application} status 2> /dev/null;done | egrep -v "STATE|online";:)'
}

function check_apps_old ()
{
if [ $# -eq 0 ]; then
for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
else
validatehost $1 || return 1
s $1 check_apps
fi
}

function check_apps ()
{
if [ -f /usr/sbin/zonename ]; then
  if [ "`zonename`" == "global" ]; then
    if [ "`whoami`" == "root" ]; then
      if [ $# -eq 0 ]; then # if no argument provided, check all zones
        for Z in `zoneadm list| grep -v global`; do
          echo "Checking apps for $Z"
          zlogin $Z '(for application in `ls /applications | grep -v wood | sed "s/\///g"`;do /applications/${application}/users/system/init.d/${application} status 2> /dev/null;done | grep -v STATE)'
        done
      else 
        zlogin $1 '(for application in `ls /applications | grep -v wood | sed "s/\///g"`;do /applications/${application}/users/system/init.d/${application} status 2> /dev/null;done | grep -v STATE)'
      fi # if $# -eq 0
    else
      echo "Must be root"
      return 1
    fi # if root
  else  # not a global zone
      for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
  fi # if global
else # /usr/sbin/zonename not present
    if [ $# -eq 0 ]; then
      for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} status 2>/dev/null; done | grep -v STATE
    else
      validatehost $1 || return 1
      s $1 check_apps
   fi
fi # if /usr/sbin/zonename is present
}



function enable_apps ()
{
if [ $# -eq 0 ]; then   # enable local applications
  for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} enable 2>/dev/null; done | grep -v STATE
else                    # enable zone applications remotely
  validatehost $1 || return 1
  s $1 enable_apps
fi
}

function disable_apps ()
{
if [ $# -eq 0 ]; then   # disable local applications
  for application in `ls /applications | grep -v wood | sed "s/\///g"`; do /applications/${application}/users/system/init.d/${application} disable 2>/dev/null; done | grep -v STATE
else                    # disable zone applications remotely
  validatehost $1 || return 1
  s $1 disable_apps
fi
}

function check_rpool_cap ()
{
mypssH "`clhosts`" /usr/sbin/zpool list -H -o name,cap rpool
}

function check_estimated_dump_size ()
{
for H in `clhosts`; do printf "%-10s: " "$H" && sre $H /usr/sbin/dumpadm -e;done
}

function check_boot_device ()
{
validatehost $1 || return 1
# echo -n "rpool disks: " && s $1 zpool status rpool | egrep -v 'rpool|mirror|state' | awk '/ONLINE/ {print $1}' | sed 's/c.*t//;s/d0$//'| xargs
# s $1 '(eeprom | egrep "boot-device="| sort)'
RED="\e[1m\e[31m"
GREEN="\e[1m\e[32m"
COLOR_NONE="\e[0m"
RPOOLDISKS=(`s $1 zpool status rpool | egrep -v 'rpool|mirror|state' | awk '/ONLINE/ {print $1}' | sed 's/c.*t//;s/d0$//' | xargs`)
BOOTDISKS=`s $1 '(eeprom | egrep "boot-device="| sort)'`
echo "rpool disks: ${RPOOLDISKS[@]}"
echo $BOOTDISKS
NL=
for D in ${RPOOLDISKS[@]}; do
[ `echo $BOOTDISKS | grep -ic $D` -eq 1 ] && echo -en "${GREEN}$D: OK${COLOR_NONE} $NL" || echo -en "${RED}NOK: $D not found in boot-device${COLOR_NONE} $NL"
NL="\\n"
done
}

function check_boot_devices_all ()
{
for H in `thosts`; do msggreen $H && check_boot_device $H;done
}

function check_boot_devices_mer ()
{
for H in `thostsmer`; do msggreen $H && check_boot_device $H;done
}

function check_boot_devices_eufo ()
{
for H in `thostseufo`; do msggreen $H && check_boot_device $H;done
}

function check_ldomdbxml ()
{
validatehost $1 || return 1
#sre $1 cat /var/opt/SUNWldm/autosave-initial/ldom-db.xml | egrep -A1  'ldom_name|boot-device|network-boot' | grep -v cpu
sre $1 cat /var/opt/SUNWldm/autosave-initial/ldom-db.xml | egrep -A1  'ldom_name|boot-device' | grep -v cpu
}

function check_ldomdbxml_all ()
{
for H in `thostsprimary`; do msggreen $H && check_ldomdbxml $H;done
}

function check_ldomdbxml_mer ()
{
for H in `thostsmerprimary`; do msggreen $H && check_ldomdbxml $H;done
}

function check_ldomdbxml_eufo ()
{
for H in `thostseufoprimary`; do msggreen $H && check_ldomdbxml $H;done
}

function check_autoboot ()
{
mypssH "`thosts`" /usr/sbin/eeprom auto-boot?
}
function check_panic ()
{
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <hostname>" && return 1
validatehost $1 || return 1
ssh $1 grep -v owner /var/adm/messages| egrep --color=auto -i 'SunOS|panic|iscsi|stuck|degraded|quorum (status|device)|unable to connect to target'
}

function check_var ()
{
#mypssH "`thosts`" '(du -hs /var/* | egrep "cluster|fm|zones|crash " | grep G ;:)'
for H in `thosts`; do msggreen $H &&  sre $H "du -hs /var/cluster/logs && du -hs /var/fm/fmd && du -hs /var/log/zones && du /hs /var/crash" | grep G ;done
}

function check_kvm_multipath ()
{
[ -z "$mypasswd" ] && definemypasswd
CMD="/home/claeyje/bin/check-multipath.pl"
for H in `kvmhosts`; do msggreen "$H" && sre $H $CMD | grep -v '[47]\/4' | egrep -v "^exit|$CMD" ;done
}

function check_ldap_duplicate_uids ()
{
DUPLICATES=`ldapsearchalluidNumbers | uniq -d`
if [ -z "$DUPLICATES" ]; then
    msggreen "OK, no duplicates found in ldap"
else
    for ID in $DUPLICATES; do
        ldapsearchalluidNumbersanduid | grep $ID
    done
fi
}

