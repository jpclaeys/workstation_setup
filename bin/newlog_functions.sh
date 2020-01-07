export TPLDIR=$HOME/tpl
export LOGDIR=$HOME/log

function insert_ticket_at_top_of_file ()
{
# This function inserts the ticket description to the beginning of a file
local TICKET FILE
if [ $# -lt 2 ]; then
  msg "Usage: $FUNCNAME <ticket> <file>"
  return 1
fi
TICKET=$1
FILE=$2
#msg "insert_ticket_at_top_of_file $TICKET $FILE"
[ ! -f "$FILE" ] && errmsg "unknown file $FILE" && return 1
get_ticket_description $TICKET || return 1
sed -i -e "1 e cat $TICKETFILE" $FILE
}

function get_ticket_description ()
{
local TICKET
if [ $# -lt 1 ]; then
  msg "Usage: $FUNCNAME <ticket> [quiet]"
  return 1
fi
TICKET=$1
if [ ${TICKET:0:2} != "IM" ]; then msg "Not an IM ticket, ignoring"; return 1;fi
TICKETFILE=${TICKETSDIR}/${TICKET}_ticket.log
[ -z $2 ] && msg "Retrieving $TICKET details from SMT. Please wait..."
(separator 100 - && echo "Ticket: $TICKET"  && separator 100 -) > $TICKETFILE
smt.sh -d $TICKET 2>/dev/null >> ${TICKETFILE}
if [ $? -ne 0 ]; then
   errmsg "Unable to retrieve $TICKET subject"
   rm ${TICKETFILE}
   return 1
fi
echo >> ${TICKETFILE}
smt.sh -i $TICKET 2>/dev/null >> ${TICKETFILE}
if [ $? -eq 5 ]; then  # jq: error (at <stdin>:): Cannot iterate over string ...
   smt.sh $TICKET | awk '/IncidentDescription/,/}/' >>  ${TICKETFILE}
   if [ $? -ne 0 ]; then
      errmsg "Unable to retrieve $TICKET full description"
      rm ${TICKETFILE}
      return 1
   fi
fi
echo >> ${TICKETFILE}
separator 100 - >> ${TICKETFILE}
[ -z $2 ] && cat ${TICKETFILE}
return 0
}

function get_ticket_all_info ()
{
local TICKET
if [ $# -lt 1 ]; then
  msg "Usage: $FUNCNAME <ticket>"
  return 1
fi
TICKET=$1
get_ticket_description $TICKET
TICKETFILE=${TICKETSDIR}/${TICKET}_ticket.log
smt.sh $TICKET | tee -a  ${TICKETFILE}
   if [ $? -ne 0 ]; then
      errmsg "Unable to retrieve $TICKET full description"
      rm ${TICKETFILE}
      return 1
   fi
}

function newlog_move_zone ()
{
[ $# -lt 4 ] && msg "Usage: $FUNCNAME <zone_name> <target_cluster> <date> <time> [primarysource secondarysource primarytarget secondarytarget]" && return 1
TARGETDIR=$LOGDIR/move_zone
TPL=$TPLDIR/move_zone_to_SRDF_Cluster_cmds.tpl
DATE=`echo $3 | sed 's:/::g'`
TIME=`echo $4 | sed 's/://g'`
LOGFILE=$TARGETDIR/move_zone_${1}_to_${2}_${DATE}_${TIME}.log
validatehost $1 || return 1
SUB="s/<zone_name>/$1/g"
SUB+=";s@<start_date>@$3@g"
SUB+=";s@<start_time>@$4@g"
if [ $# -gt 4 ]; then
  PRIMARYSOURCE=$5
  SECONDARYSOURCE=$6
  PRIMARYTARGET=$7
  SECONDARYTARGET=$8
  validatehost $PRIMARYSOURCE || return 1
  validatehost $SECONDARYSOURCE || return 1
  validatehost $PRIMARYTARGET || return 1
  validatehost $SECONDARYTARGET || return 1
  SUB+=";s/<primarysource>/$PRIMARYSOURCE/g"
  SUB+=";s/<secondarysource>/$SECONDARYSOURCE/g"
  SUB+=";s/<primarytarget>/$PRIMARYTARGET/g"
  SUB+=";s/<secondarytarget>/$SECONDARYTARGET/g"
fi
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
perl -pe "$SUB" -i $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function define_primary_and_secondary ()
{ 
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <zone_name>" && return 1
PRIMARYHOST=`cmdb zone | grep "$1;" | awk -F";" '/Primary/ {print $7}'`
SECONDARYHOST=`cmdb zone | grep "$1;" | awk -F";" '/Secondary/ {print $7}'`
EFFECTIVE_PRIMARYHOST=`zone-where $1 -q`
if [ $? -eq 0 ]; then
    if [ "$EFFECTIVE_PRIMARYHOST" != "PRIMARYHOST" ] ; then
       SECONDARYHOST=$PRIMARYHOST
       PRIMARYHOST=$EFFECTIVE_PRIMARYHOST
    fi
fi
echo "Primary host for $1: $PRIMARYHOST"
echo "Secondary host for $1: $SECONDARYHOST"
}

function newlog_decom_zone ()
{
[ $# -lt 2 ] && msg "Usage: $FUNCNAME <ticket> <zone_name> [<primary host> <secondary host>]" && return 1
TICKET=$1
HOST=$2
if [ -n "$3" ]; then
  PRIMARYHOST=$3 && echo "Primary host for $HOST: $PRIMARYHOST"
  SECONDARYHOST=$4 && echo "Secondary host for $HOST: $SECONDARYHOST"
else
  define_primary_and_secondary $HOST
fi
TYPE=${FUNCNAME#newlog_}
TARGETDIR=$LOGDIR/$TYPE
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
LOGFILE=$TARGETDIR/${TICKET}_${TYPE}_${HOST}_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
SUB="s/<zone_name>/$HOST/g"
SUB+=";s/<primary_host>/$PRIMARYHOST/"
SUB+=";s/<secondary_host>/$SECONDARYHOST/"
perl -pe "$SUB" -i $LOGFILE
insert_ticket_at_top_of_file $TICKET $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function newlog_remove_physical_server ()
{
[ $# -lt 2 ] && msg "Usage: $FUNCNAME <ticket> <hostname>" && return 1
TICKET=$1
HOST=2$
TYPE=${FUNCNAME#newlog_}
TARGETDIR=$LOGDIR/$TYPE
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
LOGFILE=$TARGETDIR/${TICKET}_${TYPE}_${HOST}_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
perl -pe "s/<hostname>/$HOST/" -i $LOGFILE
insert_ticket_at_top_of_file $TICKET $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function newlog_add_hostbased_mirrored_storage ()
{
TYPE=${FUNCNAME#newlog_}
newlog_add_storage "$@"
}

function newlog_add_srdf_storage ()
{
TYPE=${FUNCNAME#newlog_}
newlog_add_storage "$@"
}

function newlog_add_storage ()

{
# Entry vairable: TYPE : must contain the template name without "_cmds.tpl"
[ -z "$TYPE" ] && errmsg "TYPE vaiable not defined" && return 1
echo "Template type: $TYPE"
[ $# -lt 1 ] && msg "Usage: $FUNCNAME <zone_name> [<pool_name>] [<ticketnumber>] [<primary host> <secondary host>]" && return 1
if [ -n "$4" ]; then
  PRIMARYHOST=$4 && echo "Primary host for $1: $PRIMARYHOST"
  SECONDARYHOST=$5 && echo "Secondary host for $1: $SECONDARYHOST"
else
  define_primary_and_secondary $1
fi
TARGETDIR=$LOGDIR/add_storage
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
[ -n "$3" ] && TICKET=${3}
[ -n "$2" ] && POOL_NAME=$2
LOGFILE=$TARGETDIR/${TICKET}_${TYPE}_${1}_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
SUB="s/<zone_name>/$1/g"
[ -n "$POOL_NAME" ] && SUB+=";s/<pool_name>/$POOL_NAME/"
SUB+=";s/<primary_host>/$PRIMARYHOST/"
SUB+=";s/<secondary_host>/$SECONDARYHOST/"
perl -pe "$SUB" -i $LOGFILE
[ -n "$TICKET" ] && insert_ticket_at_top_of_file $TICKET $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function newlog_migrate_hostbased_mirrored_storage ()
{
TYPE=${FUNCNAME#newlog_}
newlog_migrate_storage "$@"
}

function newlog_migrate_srdf_storage ()
{
TYPE=${FUNCNAME#newlog_}
newlog_migrate_storage "$@"
}

function newlog_migrate_storage ()
{
# Entry vairable: TYPE : must contain the template name without "_cmds.tpl"
[ -z "$TYPE" ] && errmsg "TYPE vaiable not defined" && return 1
echo "Template type: $TYPE"
[ $# -lt 1 ] && msg "Usage: $FUNCNAME <zone_name> [<primary host> <secondary host>]" && return 1
if [ -n "$3" ]; then
  PRIMARYHOST=$2 && echo "Primary host for $1: $PRIMARYHOST"
  SECONDARYHOST=$3 && echo "Secondary host for $1: $SECONDARYHOST"
else
  define_primary_and_secondary $1
fi
TARGETDIR=$LOGDIR/migrate_storage
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
LOGFILE=$TARGETDIR/${TYPE}_${1}_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
SUB="s/<zone_name>/$1/g"
SUB+=";s/<primary_host>/$PRIMARYHOST/"
SUB+=";s/<secondary_host>/$SECONDARYHOST/"
perl -pe "$SUB" -i $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function newlog_decom_vm ()
{
local TICKET CLUSTER VMLIST
[ $# -lt 3 ] && msg "Usage: $FUNCNAME <ticket> <clustername> <vmlist>" && return 1
TICKET=$1; shift
CLUSTER=$1; shift
VMLIST="$@"
TYPE=${FUNCNAME#newlog_}
TARGETDIR=$LOGDIR/$TYPE
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
[ -n "$CLUSTER" ] && CLUSTERPAR="${CLUSTER}_" || CLUSTERPAR=
LOGFILE=$TARGETDIR/${TICKET}_${TYPE}_${CLUSTERPAR}`echo ${VMLIST}| sed 's/ /_/g'`_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
perl -pe "s/<vmlist>/$VMLIST/" -i $LOGFILE
perl -pe "s/<clustername>/$CLUSTER/" -i $LOGFILE
insert_ticket_at_top_of_file $TICKET $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function newlog_decom_kvm_cluster ()
{
local TICKET CLUSTER
[ $# -lt 2 ] && msg "Usage: $FUNCNAME <ticket> <clustername>" && return 1
TICKET=$1
CLUSTER=$2
TYPE=${FUNCNAME#newlog_}
TARGETDIR=$LOGDIR/$TYPE
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
LOGFILE=$TARGETDIR/${TICKET}_${TYPE}_${CLUSTER}_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
perl -pe "s/<clustername>/$CLUSTER/" -i $LOGFILE
insert_ticket_at_top_of_file $TICKET $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function newlog_decom_linux_physical ()
{
local TICKET HOSTNAME
[ $# -lt 2 ] && msg "Usage: $FUNCNAME <ticket> <hostname>" && return 1
TICKET=$1
HOSTNAME=$2
TYPE=${FUNCNAME#newlog_}
TARGETDIR=$LOGDIR/$TYPE
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
LOGFILE=$TARGETDIR/${TICKET}_${TYPE}_${HOSTNAME}_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
perl -pe "s/<hostname>/$HOSTNAME/g" -i $LOGFILE
insert_ticket_at_top_of_file $TICKET $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function newlog_add_new_ldap_user ()
{
local TICKET LASTNAME FIRSTNAME LOGIN
[ $# -lt 4 ] && msg "Usage: $FUNCNAME <ticket> <lastname> <firstname> <login>" && return 1
TICKET=$1
LASTNAME=$2
FIRSTNAME=$3
LOGIN=$4
TYPE=${FUNCNAME#newlog_}
TARGETDIR=$LOGDIR/$TYPE
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
LOGFILE=$TARGETDIR/${TICKET}_${TYPE}_${FIRSTNAME}_${LASTNAME}_${LOGIN}_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
SUB="s/<ticket>/$TICKET/g"
SUB+=";s/<lastname>/$LASTNAME/"
SUB+=";s/<firstname>/$FIRSTNAME/"
SUB+=";s/<login>/$LOGIN/"
perl -pe "$SUB" -i $LOGFILE
insert_ticket_at_top_of_file $TICKET $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

function newlog_delete_ldap_user ()
{
local TICKET LASTNAME FIRSTNAME LOGIN
[ $# -lt 2 ] && msg "Usage: $FUNCNAME <ticket> <login>" && return 1
TICKET=$1
LOGIN=$2
TYPE=${FUNCNAME#newlog_}
TARGETDIR=$LOGDIR/$TYPE
TPL=$TPLDIR/${TYPE}_cmds.tpl
TIMESTAMP=`date "+%d%m%Y"`
LOGFILE=$TARGETDIR/${TICKET}_${TYPE}_${LOGIN}_$TIMESTAMP.log
msg "Creating $LOGFILE"
cp $TPL $LOGFILE
SUB="s/<ticket>/$TICKET/g"
SUB+=";s/<login>/$LOGIN/"
perl -pe "$SUB" -i $LOGFILE
insert_ticket_at_top_of_file $TICKET $LOGFILE
confirmexecution "Do you want to edit the file $LOGFILE ?" || return 1
vi $LOGFILE
}

