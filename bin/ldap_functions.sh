export LDAPSERVER=ldapa-pk

# ------------------------------------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------------------------------------------
# Add new ldap user 
# ------------------------------------------------------------------------------------------------------------------------------------
# Ref: https://intragate.ec.europa.eu/publications/opitwiki/doku.php?id=op:nix:howto_manage_user_accounts&#adding_a_user_account

function ldapadduser ()
{
[ $# -lt 4 ] && msg "Usage: $FUNCNAME: <first_name> <last_name> <login> <uid> [-dry] [-v] [-gid=] [-ldap_server=] [-wiki] [-official] [-system] [-int_test] [-int_prod] [-dba] [-aws_cellar]" && return 1

# Set default values
# -------------------
opunix=47110
staff=10
gid=$opunix		# default value=opunix
ldap_server=$LDAPSERVER
bind_dn="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"
official=no
wiki_user=no		# grant access to the wiki for unix, dba & int prod ; not for INT TEST
system_team_member=no
int_prod_member=no
int_test_member=no
dba_member=no
aws_cellar_member=no

nfsserver='nfs-infra.isilon.opoce.cec.eu.int'
systemgroups="opsys_ux adminux aws-sysadm op-sysadm"
opunixgroups="staff opunix op-unix aws-unix"
dbagroups="rootdba admindba aws-dba op-dba"
inttestgroups="int_test aws-t-int op-t-int"
awscellargroups="staff aws-cellar-pmb aws-unix"
intprodgroup="root-int"
satgroups="sat-admin op-satellite"

# Read input parameters
# ----------------------

first_name="$1"
last_name="$2"
login=$3
uid=$4

gecos="${first_name} ${last_name}"

grep -q '\-ldap_server' <<< $@ && ldap_server=`awk -F"-ldap_server=" '{print $2}' <<< $@ | awk '{print $1}'`
grep -q '\-official'    <<< $@ && official=yes
grep -q '\-wiki'        <<< $@ && wiki_user=yes
grep -q '\-system'      <<< $@ && system_team_member=yes
grep -q '\-int_test'    <<< $@ && int_test_member=yes
grep -q '\-int_prod'    <<< $@ && int_prod_member=yes
grep -q '\-dba'         <<< $@ && dba_member=yes
grep -q '\-aws_cellar'  <<< $@ && aws_cellar_member=yes && gid=$staff
grep -q '\-gid='        <<< $@ && gid=`awk -F"-gid=" '{print $2}' <<< $@ | awk '{print $1}'`
grep -q '\-dry'         <<< $@ && dryrun="-n"  || dryrun=       #; echo $dryrun
grep -q '\-v'           <<< $@ && verbose="-v" || verbose=      #; echo $verbose

# The “official” variable is used to specify if this user is an OP official or not.
# The “wiki_user” variable is used for add the user to the Wiki group.
# The “system_team_member” variable is used for add the user to groups (opsys_ux, adminux, ldap-admin and sat-admin).
# The “int_prod_member” variable is used for add the user to the root-int group.
# The “int_test_member” variable is used for add the user to the int_test group.
# The “dba_member” variable is used for add the user to the rootdba group.

export LDAPPWD='0pocE123!!'
[ "$test" == "y" ] &&  dryrun="-n"  # force dry-run during test phase
LDAPADDCMD='ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 '"$dryrun $verbose" # && echo $LDAPADDCMD

# Check if uid already exists
ldapsearch -x -h $ldap_server -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(uid=*)" uidNumber | grep -q $uid && errmsg "uid already exists: `id $uid | cut -d' ' -f1`, aborting" && return 1

# Create “mailaddress” variable
# --------------------------------
PREFIX= && [[ $official == no ]] && PREFIX="ext."
# remove spaces from the last_name if any
lastnamemail=`echo ${last_name} | tr -d ' '`
mailaddress=`echo "${first_name}.${lastnamemail}@${PREFIX}publications.europa.eu" | tr '[:upper:]' '[:lower:]'`

# Check defined variables
# ------------------------
msgsep "Check defined variables"
cat <<EOT
first_name="$first_name"
last_name="$last_name"
login=$login
uid=$uid
gid=$gid
gecos="$gecos"
mailaddress="$mailaddress"
ldap_server=$ldap_server
official=$official
wiki_user=$wiki_user
system_team_member=$system_team_member
int_prod_member=$int_prod_member
int_test_member=$int_test_member
dba_member=$dba_member
aws_cellar_member=$aws_cellar_member
nfsserver=$nfsserver
dryrun=$dryrun
verbose=$verbose
ldap_cmd=$LDAPADDCMD
EOT

confirmexecution "Do you want to proceed with the user creation ?" || return 1

# Then start user creation:
msgsep "start user creation"
# ---------------------------------------
# Define the "SolarisAttrKeyValue"
# ---------------------------------------
{
# system team member
if [[ $system_team_member == yes ]]; then
  msgsep Define the SolarisAttrKeyValue for system users
  solarisattrkeyvalue="SolarisAttrKeyValue: type=normal;roles=opsys_ux"
# DBA team member
elif [[ $dba_member == yes ]]; then
  msgsep Define the SolarisAttrKeyValue for dba users
  solarisattrkeyvalue="SolarisAttrKeyValue: type=normal;roles=orastor,rootdba,oracle"
# INT PROD team member
elif [[ $int_prod_member == yes ]]; then
  msgsep Define the SolarisAttrKeyValue for int prod users
  solarisattrkeyvalue="SolarisAttrKeyValue: type=normal;roles=root-int"
else
  solarisattrkeyvalue=
fi
[[ -n $solarisattrkeyvalue ]] && echo "solarisattrkeyvalue=$solarisattrkeyvalue" && echo
}

# Create the user
# ---------------------------------------
msgsep Create the user
{
eval "$LDAPADDCMD" <<EOT
dn: uid=${login},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
uid: ${login}
loginShell: /bin/bash
uidNumber: ${uid}
gidNumber: ${gid}
homeDirectory: /home/${login}
shadowLastChange: 0
shadowMax: -1
objectClass: account
objectClass: posixaccount
objectClass: shadowaccount
objectClass: SolarisUserAttr
objectClass: top
gecos: ${gecos}
cn: ${gecos}
userPassword: {CRYPT}`perl -e  'print crypt('${login}', '${login}')' `
$solarisattrkeyvalue
EOT
}

# Groups for opunix users
# ---------------------------------------
{
if [[ $gid -eq $opunix ]]; then
msgsep Add user to opunix groups
for group in $opunixgroups; do
eval "$LDAPADDCMD" <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
fi
}

# Additional groups for dba's
# ---------------------------------------
{
if [[ $dba_member == yes ]]; then
msgsep Add user to DBA groups
for group in $dbagroups; do
eval "$LDAPADDCMD" <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
fi
}

# Additional groups for INT TEST team
# ---------------------------------------
{
if [[ $int_test_member == yes ]]; then
msgsep Add user to INT TEST groups
for group in $inttestgroups; do
eval "$LDAPADDCMD" <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
fi
}


# Additional groups for INT PROD team
# ---------------------------------------
{
if [[ $int_prod_member == yes ]]; then
msgsep Add user to INT PROD group
eval "$LDAPADDCMD" <<EOT
dn: cn=$intprodgroup,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
fi
}

# Additional groups for SYSTEM team
# ---------------------------------------
{
if [[ $system_team_member == yes ]]; then
msgsep Add user to SYSTEM groups
for group in $systemgroups; do
eval "$LDAPADDCMD" <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done

msgsep Add user to ldap-admins group
eval "$LDAPADDCMD" <<EOT
dn: cn=ldap-admins,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: member
member: uid=$login,ou=people,dc=opoce,dc=cec,dc=eu,dc=int
EOT

msgsep Add user to satellite groups
for group in $satgroups; do
eval "$LDAPADDCMD" <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: uniqueMember
uniqueMember: uid=$login,ou=people,dc=opoce,dc=cec,dc=eu,dc=int
EOT
done
fi
}

# Additional groups for aws_cellar users
# ---------------------------------------
{
if [[ $aws_cellar_member == yes ]]; then
msgsep Add user to AWS_CELLAR groups
for group in $awscellargroups
do
eval "$LDAPADDCMD" <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
fi
}

# Additional group for wiki
# ---------------------------------------
{
if [[ $wiki_user == yes ]]; then
msgsep Add user to the wiki group
eval "$LDAPADDCMD" <<EOT
dn: cn=user,ou=wiki,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
fi
}

#  Add the auto_home map
# ---------------------------------------
{
msgsep Add the auto_home map for the user
eval "$LDAPADDCMD" <<EOT
dn: automountKey=${login},automountMapName=auto_home,dc=opoce,dc=cec,dc=eu,dc=int
automountInformation: -soft ${nfsserver}:/home/&
automountKey: ${login}
objectClass: automount
objectClass: top
EOT
}

# Add the email alias
# ---------------------------------------
{
msgsep Add the email alias for the user
eval "$LDAPADDCMD" <<EOT
dn: cn=${login},ou=aliases,dc=opoce,dc=cec,dc=eu,dc=int
objectClass: mailgroup
objectClass: nismailalias
objectClass: top
mail:  ${login}
cn: ${login}
mgrpRFC822MailMember: ${mailaddress}
rfc822mailMember: ${mailaddress}
EOT
}

# 
# Get current ldap entry values for the user
# -------------------------------------------
msgsep Get current ldap entry values for the user
ldapsearchuserentries $login

# Create the homedir
# -------------------
msgsep "Goto $ldap_server and execute the following commands"
cat<<EOT
cd /net/$nfsserver/home
mkdir ${login} && chown ${login}.${gid} ${login} && ls -ld ${login}
EOT

}

# ------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------

function ldapdeleteuser ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCNAME <userid> [-ldap_server=] [-dry] [-v]" && return 1
login=$1

LDAPPWD='0pocE123!!'
BINDDN="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"
GROUPDN=ou=group,dc=opoce,dc=cec,dc=eu,dc=int

grep -q '\-ldap_server' 2> /dev/null <<< $@ && LDAPSERVER=`awk -F"-ldap_server=" '{print $2}' <<< $@ | awk '{print $1}'`;
grep -q '\-dry' 2> /dev/null <<< $@ && dryrun="-n" || dryrun=
grep -q '\-v' 2> /dev/null <<< $@ && verbose="-v" || verbose=

LDAPCMD='ldapmodify -w $LDAPPWD -D "$BINDDN" -h $LDAPSERVER -p 389 ' # && echo $LDAPADDCMD

#------------------------------
# Check the defined variables
#------------------------------
{
echo "
LDAPSERVER=$LDAPSERVER
BINDDN=$BINDDN
login=$login
LDAPCMD=$LDAPCMD
dryrun=$dryrun
verbose=$verbose
"
}

# Get current ldap entry values for the user
# -------------------------------------------
msgsep Get current ldap entry values for the user
ldapsearchuserentries $login

confirmexecution "Do you want to proceed with the user removal?" || return 1

# Start removing the user
# ------------------------

# Remove the user
# ----------------
msgsep Remove the user
eval "$LDAPCMD" $dryrun $verbose <<EOT
dn: uid=${login},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
changetype: delete
EOT

# Remove the auto_home map
# -------------------------
msgsep Remove the auto_home map
eval "$LDAPCMD" $dryrun $verbose <<EOT
dn: automountKey=${login},automountMapName=auto_home,dc=opoce,dc=cec,dc=eu,dc=int
changetype: delete
EOT

# Remove the email alias
# -----------------------
msgsep Remove the email alias
eval "$LDAPCMD" $dryrun $verbose <<EOT
dn: cn=${login},ou=aliases,dc=opoce,dc=cec,dc=eu,dc=int
changetype: delete
EOT

# Remove the user from the groups (memberUid)
# --------------------------------------------

UG=`ldapsearchusergroups $login`
msgsep Remove user from $UG
{
for group in $UG
do
eval "$LDAPCMD" $dryrun $verbose <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
delete: memberUid
memberUid: $login
EOT
done
}

# Remove the user from the ldap-admins groups (member)
# ------------------------------------------------------
group=ldap-admins
if `ldapsearch -x -h $LDAPSERVER -b $GROUPDN cn=$group | grep -q $login`; then
  msgsep Remove user from group $group
  eval "$LDAPCMD" $dryrun $verbose <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
delete: member
member: uid=$login,ou=people,dc=opoce,dc=cec,dc=eu,dc=int
EOT
fi

# Remove the user from the satellite groups (uniqueMember)
# -----------------------------------------------------------
satgroups="op-satellite sat-admin"
for group in $satgroups; do
if `ldapsearch -x -h $LDAPSERVER -b $GROUPDN cn=$group | grep -q $login`; then 
  msgsep Remove user from group $group
  eval "$LDAPCMD" $dryrun $verbose <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
delete: uniqueMember
uniqueMember: uid=$login,ou=people,dc=opoce,dc=cec,dc=eu,dc=int
EOT
fi
done

# Remove the user from the wiki
# --------------------------------
{
ldapsearch -x -h $LDAPSERVER -b 'cn=user,ou=wiki,dc=opoce,dc=cec,dc=eu,dc=int' memberuid | grep -q $login
if [ $? -eq 0 ]; then
msgsep Remove user from group user,wiki
eval "$LDAPCMD" $dryrun $verbose <<EOT
dn: cn=user,ou=wiki,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
delete: memberUid
memberUid: $login
EOT
fi
}

# Get current ldap entry values for the user
# -------------------------------------------
[ -z "$dryrun" ] && ldapsearchuserentries $login

}


# ------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------

function ldapresetpasswd ()
{
local LOGIN NEWPWDCLEAR NEWPASSWD
[ "$#" -eq 0 ] && echo "Usage: $FUNCNAME <userid> [<new passwd>] [-ldap_server=] [-dry]" && return 1
id $1 >/dev/null 2>&1 ; [ $? -ne 0 ] && errmsg "no such user $1" && return 1
LOGIN=$1
NEWPWDCLEAR=$LOGIN
[ -n "$2" ] && NEWPWDCLEAR="$2"

ldap_server=$LDAPSERVER
grep -q '\-ldap_server' <<< $@ && ldap_server=`awk -F"-ldap_server=" '{print $2}' <<< $@ | awk '{print $1}'`
grep -q '\-dry'         <<< $@ && dryrun="-n"  || dryrun=       #; echo $dryrun

bind_dn="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"

# Set the LDAP admin password
LDAPPWD='0pocE123!!'
echo "Resetting password for '$LOGIN' to '$NEWPWDCLEAR'"

# get current passwd
ldapsearchuserpasswd $LOGIN

NEWPASSWD=`perl -e  'print crypt('${NEWPWDCLEAR}', '${NEWPWDCLEAR}')'` && echo "New passwd: {CRYPT}$NEWPASSWD"

confirmexecution "Do you want to proceed with the password reset for $LOGIN ?" || return 1

# Reset the password to the login name
{
ldapmodify -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 $dryrun <<EOT
dn: uid=${LOGIN},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
replace: userPassword
userPassword: {CRYPT}$NEWPASSWD
EOT
}

# ------------------------------------------------------------------------------------------------------------------------------------

# check new password
ldapsearchuserpasswd $LOGIN
}

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
[ "$#" -eq 0 ] && echo "Usage: $FUNCNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=Aliases,dc=opoce,dc=cec,dc=eu,dc=int' cn=$1 | grep -v ^version
}

function ldapsearchemail ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=Aliases,dc=opoce,dc=cec,dc=eu,dc=int' cn=$1 rfc822MailMember | grep ^rfc822MailMember | awk '{print $2}'
}

function ldapsearchuser ()
{
local FILTER
[ "$#" -eq 0 ] && echo "Usage: $FUNCNAME <userid>" && return 1
ldapsearchexists || return 1
FILTER='^(dn|uid|loginShell|uidNumber|gidNumber|homeDirectory|gecos|cn|SolarisAttrKeyValue):'
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' uid=$1 | egrep $FILTER
}

function ldapsearchgecos ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' uid=$1 gecos | awk -F":" '/gecos/ {print $NF}'| xargs
}

function ldapsearchusergidnumber ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCNAME <userid>" && return 1
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=people,dc=opoce,dc=cec,dc=eu,dc=int' uid=claeyje gidNumber | awk '/gidNumber/ {print $NF}'
}
function ldapsearchsolarisroles ()
{
[ "$#" -eq 0 ] && echo "Usage: $FUNCNAME <userid>" && return 1
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
if [ "$2" == "-v" ]; then
  ldapsearch -x -h $LDAPSERVER -b 'dc=opoce,dc=cec,dc=eu,dc=int' "(|(memberuid=$1)(uniquemember="$F")(member=$F))" cn
else
  ldapsearch -x -h $LDAPSERVER -b 'dc=opoce,dc=cec,dc=eu,dc=int' "(|(memberuid=$1)(uniquemember="$F")(member=$F))" cn | awk '/cn:/ {print $NF}' | sort | xargs
fi
}

function ldapsearchopdt ()
{
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <opdtxxx>" && return 1
#ldapsearch 2> /dev/null -h $LDAPSERVER -b 'ou=netgroup,dc=opoce,dc=cec,dc=eu,dc=int' cn=admin | grep -v ^version | egrep -i "cn:|dn:|objectclass|$1"
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=netgroup,dc=opoce,dc=cec,dc=eu,dc=int' cn=* | grep -v ^version | egrep -i "cn:|dn:|objectclass|$1" | grep -B4 -i $1 | grep -iv objectclass
}

function ldapsearchallnetgroups ()
{
ldapsearchexists || return 1
ldapsearch -x -h $LDAPSERVER -b 'ou=netgroup,dc=opoce,dc=cec,dc=eu,dc=int' | grep cn= | sed 's/=/,/' | awk -F, '{print $2}'| sort
}

function ldapsearchnetgrouphost ()
{
ldapsearchexists || return 1
[ $# -lt 2 ] && msg "Usage: $FUNCNAME <netgroup> <host>" && return 1
ldapsearch -x -h $LDAPSERVER -b 'ou=netgroup,dc=opoce,dc=cec,dc=eu,dc=int' cn=$1 | grep $2
}

function ldapsearchnetgroupallhosts ()
{
ldapsearchexists || return 1
[ $# -lt 1 ] && msg "Usage: $FUNCNAME <netgroup>" && return 1
ldapsearch -x -h $LDAPSERVER -b 'ou=netgroup,dc=opoce,dc=cec,dc=eu,dc=int' cn=$1 | grep nisNetgroupTriple
}

function ldapsearchnfs_cellar_pz_public_ro ()
{
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <host>" && return 1
ldapsearchnetgrouphost nfs_cellar_pz_public_ro $1
}

function ldapsearchuserfull ()
{
local ldap_server
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <user> [-ldap_server=]" && return 1
definemypasswd
ldap_server=$LDAPSERVER
grep -q '\-ldap_server' <<< $@ && ldap_server=`awk -F"-ldap_server=" '{print $2}' <<< $@ | awk '{print $1}'`
sr $ldap_server slapcat -n2 -a uid=$1
}

function ldapsearchuserpasswd ()
{
local ldap_server
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <user> [-ldap_server=]" && return 1
ldap_server=$LDAPSERVER
grep -q '\-ldap_server' <<< $@ && ldap_server=`awk -F"-ldap_server=" '{print $2}' <<< $@ | awk '{print $1}'`
LOCALHOST=`uname -n | cut -d. -f1`
if [ "$LOCALHOST" == "$ldap_server" ]; then
   check_root || return 1
   slapcat -n2 -a uid=$1 | grep userPassword 2> /dev/null
else
   definemypasswd
   sr $ldap_server slapcat -n2 -a uid=$1 | grep userPassword 2> /dev/null
fi
}

function ldapsearchallgroups ()
{
ldapsearchexists || return 1
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=group,dc=opoce,dc=cec,dc=eu,dc=int' cn | awk '/^cn/ {print $2}' | sort -u
}

function ldapsearchgroupmembers ()
{
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <group_name>" && return 1
#ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=group,dc=opoce,dc=cec,dc=eu,dc=int' cn=$1 | awk '/memberUid:/ {print $2}' | sort | xargs
ldapsearch -x 2> /dev/null -h $LDAPSERVER -b 'ou=group,dc=opoce,dc=cec,dc=eu,dc=int' cn=$1 | grep -i member | awk '{print $2}' | sort 
}

function ldapsearch_aws-cellar-pmb_members ()
{
ldapsearchgroupmembers aws-cellar-pmb
}

function ldapsearchautohome ()
{
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <uid>" && return 1
# ldapsearch -x 2> /dev/null -h $LDAPSERVER -o ldif-wrap=no -b 'automountKey='$1',automountMapName=auto_home,dc=opoce,dc=cec,dc=eu,dc=int' | egrep "$1|automountInformation"
FILTER='^(dn|automountInformation|automountKey):'
ldapsearch -x -o ldif-wrap=no -h $LDAPSERVER -b 'dc=opoce,dc=cec,dc=eu,dc=int' -s sub "(&(objectclass=automount)(automountkey=$1))"  | egrep $FILTER
}

# Get current ldap entry values for the user
# -------------------------------------------
function ldapsearchuserentries ()
{
ldapsearchexists || return 1
[ $# -eq 0 ] && msg "Usage: $FUNCNAME <user>" && return 1
msgsep Get current ldap entry values for the user: $1
msgsep user info
ldapsearchuser $1
msgsep user groups list
ldapsearchusergroupsfull $1
msgsep user mail
ldapsearchemail $1
msgsep user autohome
ldapsearchautohome $1
}

