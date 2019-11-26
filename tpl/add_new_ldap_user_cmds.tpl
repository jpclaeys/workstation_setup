Add new ldap user cmds template
--------------------------------

Ref: https://intragate.ec.europa.eu/publications/opitwiki/doku.php?id=op:nix:howto_manage_user_accounts&#adding_a_user_account

# Set the LDAP admin password so it is not plaintext and not in .bash_history 
read -p "Enter the password for the LDAP administrator: " LDAPPWD

# Get the first available uid
get_first_free_uid 30200 | grep -i First

FIRST_NAME=
LAST_NAME=
USERLOGIN=
USERID=


1.2.2 Create the LDAP definitions
----------------------------------
# On one of the PROD LDAP servers (ldapa-pk or ldapb-pk), do :

{
export ldap_server=ldapa-pk
export bind_dn="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"
export first_name=$FIRST_NAME
export last_name=$LAST_NAME
export login=$USERLOGIN
export uid=$USERID
export gecos="${first_name} ${last_name}"
export official=no
export halian_user=no
export system_team_member=no
export int_prod_member=no
export int_test_member=no
export dba_member=no
}

The “official” variable is used to specify if this user is an OP official or not.
The “halian_user” variable is used for add the user to the Wiki group.
The “system_team_member” variable is used for add the user to groups (opsys_ux, adminux, ldap-admin and sat-admin).
The “int_prod_member” variable is used for add the user to the root-int group.
The “int_test_member” variable is used for add the user to the int_test group.
The “dba_member” variable is used for add the user to the rootdba group.

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
halian_user=$halian_user
system_team_member=$system_team_member
int_prod_member=$int_prod_member
int_test_member=$int_test_member
dba_member=$dba_member
"
}


# Then, we create “mailaddress” variable
-----------------------------------------

if [[ $official == yes ]]; then
	export mailaddress="${first_name}.${last_name}@publications.europa.eu"
else
	export mailaddress="${first_name}.${last_name}@ext.publications.europa.eu"
fi



# Then start user creation:
----------------------------
{
if [[ $system_team_member == yes ]]; then
 
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: uid=${login},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
uid: ${login}
loginShell: /bin/bash
uidNumber: ${uid}
gidNumber: 47110
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
SolarisAttrKeyValue: type=normal;roles=opsys_ux
EOT
 
else
 
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: uid=${login},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
uid: ${login}
loginShell: /bin/bash
uidNumber: ${uid}
gidNumber: 47110
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
EOT
 
fi
}

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

{
if [[ $dba_member == yes ]]; then
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=rootdba,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
fi
}

{
if [[ $int_test_member == yes ]]; then
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=int_test,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
fi
}

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

{
if [[ $halian_user == yes ]]; then
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=user,ou=wiki,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
fi
}

#  Add the auto_home map for this user this way:

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

# Add the email alias for this user:
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


1.2.3 Create the HOME of the user
----------------------------------
Elect one of the LDAP server to store the HOME of the user. It is either ladpa-pk or ldapb-pk. 
On one of these servers, you should run as root:

{
login= 				# set the login user

cd /net/nfs-infra.isilon.opoce.cec.eu.int/home
mkdir ${login}
chown ${login}.opunix ${login}
ls -ls ${login}
}

2. Important note:
-------------------

It takes some time to populate the ldap modifications on all of the servers.

To be sure that ldap is updated on a specific server, just restart the sssd service:

# systemctl restart sssd. 

