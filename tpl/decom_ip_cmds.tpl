====================================================================================================================================

3.3.2 Network: Remove IP and DNS entry for the server, the bkp and the consoles
---------------------------------------------------------------------------------

Connect to http://resop/ip and fill in the form

- enter the hosts
- enter the bkp-hosts
- enter the consoles

{
HL=`eval $CLUSTER` && echo $HL
CONSL=`for H in $HL; do echo ${H}-sc;done|xargs` && echo $CONSL
# Hosts IP @
for H in $HL; do printf "%-12s: " $H && dig ${H}.opoce.cec.eu.int +short;done
# backup IP @
for H in $HL; do printf "%-12s: " bkp-${H} && dig bkp-${H}.opoce.cec.eu.int +short;done
# Consoles IP @
for H in $CONSL; do printf "%-12s: " ${H} && dig ${H}.opoce.cec.eu.int +short;done
}

# Create the excel request file
generate_ip_delete_hostlist_records $HL $CONSL | tee ~/snet/data.txt

# On Windows, create a new excel sheet based on the "OPS-RFC-DNS-RF2.3-delete.xltx" template
run DNS_delete_entry macro

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $HL $CONSL

====================================================================================================================================


3.3.2 Network: Remove IP and DNS entry for the server
------------------------------------------------------

Connect to http://resop/ip and fill in the form

- enter the hosts
- enter the CNAME

HOST=<hostname>
CNAME=
HL="$HOST $CNAME"

# Hosts IP @
printf "%-12s: " $HOST && dig ${HOST}.opoce.cec.eu.int +short

# Create the excel request file (template: OPS-RFC-DNS-delete.xltx)
generate_ip_delete_hostlist_records $HL | tee ~/snet/data.txt

# Create the ticket for SNET
create_delete_ip_ticket_for_SNET $HL

====================================================================================================================================

