
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
sed -i -e "1 e /usr/bin/cat $TICKETFILE" $FILE
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
[ -z $2 ] && /usr/bin/cat ${TICKETFILE}
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

function get_ticket_journal ()
{
if [ $# -lt 1 ]; then
  msg "Usage: $FUNCNAME <ticket>"
  return 1
fi
smt.sh $1 | awk '/IncidentID/ || /JournalUpdates/,/]/'
}

function mytickets ()
{
smt.sh -a claeyje | awk '/IncidentID/ {print $NF}' | sed 's/\"//g'
}

function mytickets_description ()
{
SEP=`separator 132 -`
smt.sh -a claeyje | awk '/IncidentID/ || /Description/,/}/' | sed 's/\"//g;s/,$//' | perl -pe 's/(Description: {)/\n'$SEP'\n\1/' && echo $SEP
}

function mytickets_summary ()
{
#smt.sh -a claeyje  | egrep "IncidentID|Server Name|Action" | tac | sed "s/,$//;s/<//g;s/>//g" | xargs -n5 | sort -t":" -k5
smt.sh -a claeyje  | egrep "IncidentID|Server Name|Action" | tac | sed "s/,$//;s/<//g;s/>//g"
}

