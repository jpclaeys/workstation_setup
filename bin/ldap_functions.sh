export LDAPSERVER=ldapa-pk

function ldapsearchexists ()
{
#if [ "`uname -s`" == "SunOS" ] ; then
  RC=`which ldapsearch > /dev/null 2>&1; echo $?`
  if [ $RC -ne 0 ]; then
    errmsg "ldapsearch not found"
  return 1
  fi
#else
#  errmsg "Not Solaris, exiting ..."
#  return 1
#fi
}

function ldapsearchaliases ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCTNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=Aliases,dc=opoce,dc=cec,dc=eu,dc=int' cn=$1 | grep -v ^version
}

function ldapsearchemail ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCTNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=Aliases,dc=opoce,dc=cec,dc=eu,dc=int' cn=$1 rfc822MailMember | grep rfc822MailMember | awk '{print $2}'
}

function ldapsearchuser ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCTNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' uid=$1 | grep -v ^version
}

function ldapsearchgecos ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCTNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' uid=$1 gecos | awk -F":" '/gecos/ {print $NF}'| xargs
}

function ldapsearchusergidnumber ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCTNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' uid=claeyje gidNumber | awk '/gidNumber/ {print $NF}'
}
function ldapsearchsolarisroles ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCTNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' uid=$1 | grep SolarisAttrKeyValue
}

function ldapsearchallusers ()
{
ldapsearchexists || return 1
ldapsearch -x -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(objectclass=*)"
}

function ldapsearchallusersgecosanduid ()
{
ldapsearchexists || return 1
ldapsearch -x -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(objectclass=*)" gecos
}

function ldapsearchallusersgecos ()
{
ldapsearchexists || return 1
ldapsearch -x -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(objectclass=*)" gecos | grep gecos| cut -d' ' -f2-
}

function ldapsearchalluidNumbersanduid()
{
ldapsearchexists || return 1
ldapsearch -x -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(uid=*)" uidNumber | sed '1,2d' | grep . | sed 'N;s/\nuid/ uid/;P;D' |sed 's/,/ /g;s/=/ /'| awk '{print $NF, $3 }'| sort
}

function ldapsearchalluidNumbers ()
{
ldapsearchexists || return 1
ldapsearch -x -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(uid=*)" uidNumber | awk '/uidNumber/ {print $NF}' | sort
}

function ldapsearchautomount ()
{
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <uid>" && return 1
ldapsearch -x -o ldif-wrap=no -h $LDAPSERVER -b 'dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(&(objectclass=automount)(automountkey=$1))"
}

function ldapsearchallentries ()
{
ldapsearchexists || return 1
ldapsearch -x -o ldif-wrap=no -h $LDAPSERVER -b 'dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(objectclass=*)"
}

function ldapsearchusergroups ()
{
local F
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <uid>" && return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=group,dc=opoce,dc=cec,dc=eu,dc=int' memberuid=$1| awk '/cn:/ {print $NF}' | sort | xargs
}

function ldapsearchusergroupsfull ()
{
local F
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <uid>" && return 1
# ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=group,dc=opoce,dc=cec,dc=eu,dc=int' memberuid=$1| awk '/cn:/ {print $NF}' | sort | xargs
F="uid=$1,ou=people,dc=opoce,dc=cec,dc=eu,dc=int"
ldapsearch -x -h $LDAPSERVER -b 'ou=group,dc=opoce,dc=cec,dc=eu,dc=int' "(|(memberuid=$1)(uniquemember="$F")(member=$F))" cn | awk '/cn:/ {print $NF}' | sort | xargs
}

function ldapsearchopdt ()
{
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <opdtxxx>" && return 1
#ldapsearch 2> /dev/null -h $LDAPSERVER -b 'ou=netgroup,dc=opoce,dc=cec,dc=eu,dc=int' cn=admin | grep -v ^version | egrep -i "cn:|dn:|objectclass|$1"
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=netgroup,dc=opoce,dc=cec,dc=eu,dc=int' cn=* | grep -v ^version | egrep -i "cn:|dn:|objectclass|$1" | grep -B4 -i $1 | grep -iv objectclass
}


