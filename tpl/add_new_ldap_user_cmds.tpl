Add new ldap user cmds template
--------------------------------

Ref: https://intragate.ec.europa.eu/publications/opitwiki/doku.php?id=op:nix:howto_manage_user_accounts&#adding_a_user_account

# Set the LDAP admin password so it is not plaintext and not in .bash_history 
read -p "Enter the password for the LDAP administrator: " LDAPPWD
0pocE123!!

# Get the first available uid
get_first_free_uid 30250 | grep -i First

FIRST_NAME=<firstname>
LAST_NAME=<lastname>
USERLOGIN=<login>
USERID=
GIDNUMBER=47110  # opunix

1.2.2 Create the LDAP definitions
----------------------------------
# On one of the PROD LDAP servers (ldapa-pk or ldapb-pk), do :

{
export ldap_server=$LDAPSERVER
export bind_dn="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"
export first_name=$FIRST_NAME
export last_name=$LAST_NAME
export login=$USERLOGIN
export uid=$USERID
export gecos="${first_name} ${last_name}"
export official=no
export wiki_user=yes              # grant access to the wiki for unix, dba & int prod ; not for INT TEST
export system_team_member=no
export int_prod_member=no
export int_test_member=no
export dba_member=no
}

# The “official” variable is used to specify if this user is an OP official or not.
# The “wiki_user” variable is used for add the user to the Wiki group.
# The “system_team_member” variable is used for add the user to groups (opsys_ux, adminux, ldap-admin and sat-admin).
# The “int_prod_member” variable is used for add the user to the root-int group.
# The “int_test_member” variable is used for add the user to the int_test group.
# The “dba_member” variable is used for add the user to the rootdba group.

# Create “mailaddress” variable
--------------------------------
{
PREFIX= && [[ $official == no ]] && PREFIX="ext."
# remove spaces from the last_name if any
lastnamemail=`echo ${last_name} | tr -d ' '` && echo $lastnamemail
#export mailaddress="${first_name}.${lastnamemail}@${PREFIX}publications.europa.eu" && echo $mailaddress
export mailaddress=`echo "${first_name}.${lastnamemail}@${PREFIX}publications.europa.eu" | tr '[:upper:]' '[:lower:]'` && echo $mailaddress
}

!!! Double check the mail address against the outlook address book !!!

# Check the defined variables
------------------------------
{
echo "
ldap_server=$ldap_server
bind_dn=$bind_dn
first_name=$first_name
last_name=$last_name
login=$login
uid=$uid
gecos=$gecos
official=$official
wiki_user=$wiki_user
system_team_member=$system_team_member
int_prod_member=$int_prod_member
int_test_member=$int_test_member
dba_member=$dba_member
mailaddress=$mailaddress
"
}

# Then start user creation:
----------------------------
# Define the "SolarisAttrKeyValue"
----------------------------------
{
# system team member
if [[ $system_team_member == yes ]]; then
  SOLARISATTRKEYVALUE="SolarisAttrKeyValue: type=normal;roles=opsys_ux"
# DBA team member
elif [[ $dba_member == yes ]]; then
  SOLARISATTRKEYVALUE="SolarisAttrKeyValue: type=normal;roles=orastor,rootdba,oracle"
# INT PROD team member
elif [[ $int_prod_member == yes ]]; then
  SOLARISATTRKEYVALUE="SolarisAttrKeyValue: type=normal;roles=root-int"
else
  SOLARISATTRKEYVALUE=
fi
echo "SOLARISATTRKEYVALUE=$SOLARISATTRKEYVALUE"
}

# Create the user
------------------
{
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: uid=${login},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
uid: ${login}
loginShell: /bin/bash
uidNumber: ${uid}
gidNumber: ${GIDNUMBER}
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
$SOLARISATTRKEYVALUE
EOT
}

# Obsolete: already done durin user creation
# {
# if [[ $dba_member == yes ]]; then
# ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
# dn: uid=${login},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
# changetype: modify
# add: SolarisAttrKeyValue
# SolarisAttrKeyValue: type=normal;roles=orastor,rootdba,oracle
# EOT
# fi
# }

# Groups for all users
{
for group in staff opunix op-unix aws-unix
do
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
}

# Additional groups for dba's
{
if [[ $dba_member == yes ]]; then
for group in rootdba admindba aws-dba op-dba; do
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
fi
}

# Additional groups for INT TEST team
{
if [[ $int_test_member == yes ]]; then
for group in int_test aws-t-int op-t-int; do
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
fi
}


# Additional groups for INT PROD team
{
if [[ $int_prod_member == yes ]]; then
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=root-int,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
fi
}


# Additional groups for SYSTEM team
{
if [[ $system_team_member == yes ]]; then
for group in opsys_ux adminux aws-sysadm op-sysadm
do			
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
 
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=ldap-admins,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: member
member: uid=$login,ou=people,dc=opoce,dc=cec,dc=eu,dc=int
EOT
 
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=sat-admin,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: uniqueMember
uniqueMember: uid=$login,ou=people,dc=opoce,dc=cec,dc=eu,dc=int
EOT
fi
}

# Additional group for wiki
{
if [[ $wiki_user == yes ]]; then
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=user,ou=wiki,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
fi
}

#  Add the auto_home map 
{
NFSSERVER='nfs-infra.isilon.opoce.cec.eu.int'
 
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: automountKey=${login},automountMapName=auto_home,dc=opoce,dc=cec,dc=eu,dc=int
automountInformation: -soft ${NFSSERVER}:/home/&
automountKey: ${login}
objectClass: automount
objectClass: top
EOT
}

# Add the email alias
{
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
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

1.2.3 Check group membership of the new user
----------------------------------------------

ldapsearchusergroups <login> 
 OR
id <login>
# Compare with another member if the same team

1.2.4 Create the HOME of the user
----------------------------------
Elect one of the LDAP server to store the HOME of the user. It is either ladpa-pk or ldapb-pk. 
On one of these servers, you should run as root:

{
login=<login> 			# set the login user
cd /net/nfs-infra.isilon.opoce.cec.eu.int/home
mkdir ${login}
chown ${login}.GIDNUMBER ${login}
ls -ld ${login}
}

3. Puppet configuration
------------------------
For INT TEST users, update the user_attr in puppet (Cfr. add_solaris_roles_to_int_test_user.tpl)

4. Important note:
-------------------

It takes some time to populate the ldap modifications on all of the servers.

To be sure that ldap is updated on a specific server, just restart the sssd service:

# systemctl restart sssd. 


