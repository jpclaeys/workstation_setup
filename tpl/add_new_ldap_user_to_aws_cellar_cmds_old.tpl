Add new ldap aws-cellar user cmds template
-------------------------------------------

Ref: https://intragate.ec.europa.eu/publications/opitwiki/doku.php?id=op:nix:howto_manage_user_accounts&#adding_a_user_account

# Set the LDAP admin password so it is not plaintext and not in .bash_history 
read -p "Enter the password for the LDAP administrator: " LDAPPWD
0pocE123!!

# Get the first available uid
get_first_free_uid 30200 | grep -i First

FIRST_NAME=<firstname>
LAST_NAME=<lastname>
USERLOGIN=<login>
USERID=
GIDNUMBER=10    # staff
awscellargroups="staff aws-cellar-pmb aws-unix"

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
export mailaddress="${first_name}.${last_name}@ext.publications.europa.eu"
}

# Check the defined variables
{
echo "
ldap_server=$ldap_server
bind_dn=$bind_dn
first_name=$first_name
last_name=$last_name
login=$login
uid=$uid
gecos=$gecos
mailaddress=$mailaddress
"
}

# Then start user creation:
{
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: uid=${login},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
uid: ${login}
loginShell: /bin/bash
uidNumber: ${uid}
gidNumber: $GIDNUMBER
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
}

{
for group in $awscellargroups
do
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
add: memberUid
memberUid: $login
EOT
done
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

login=<login> 				# set the login user

{
cd /net/nfs-infra.isilon.opoce.cec.eu.int/home
mkdir <login>; chown <login>.$GIDNUMBER <login>; ls -ldh <login>
}

2. Upload the new ldap data to aws
-----------------------------------

/root/ldap-tools/upload-to-aws.sh now
grep AWS /var/log/messages | grep -i "$(date "+%b %e %H")"


3. Important note:
-------------------

It takes some time to populate the ldap modifications on all of the servers.

To be sure that ldap is updated on a specific server, just restart the sssd service:

# systemctl restart sssd. 

4. Add user in the "users" group
---------------------------------

TIMESTAMP=`date "+%Y%m%d"` && echo $TIMESTAMP
cd /etc
grep ^users group
perl -pe 's/^(users.*)/\1,<login>/' -i.bak_$TIMESTAMP group
grep <login> group

5. Create the .ssh/config file
-------------------------------

mkdir /home/<login>/.ssh
echo "Host bastion.op.aws.cloud.tech.ec.europa.eu
ServerAliveInterval 40" > /home/<login>/.ssh/config
chmod 700 /home/<login>/.ssh
chmod 644 /home/<login>/.ssh/config
chown -R <login>.$GIDNUMBER /home/<login>

5. Grant ssh access from the user'oppc to the aws management hosts (opvmwsaws01 and opvmwsaws02)
-------------------------------------------------------------------------------------------------
# Add <login> to /etc/hosts.allow

cd /etc
ls -l hosts.allow
TIMESTAMP=`date "+%Y%m%d"` && echo $TIMESTAMP
# Validate the oppc
host <oppcname>.publications.win
cp hosts.allow hosts.allow.$TIMESTAMP
echo "sshd: <oppcname>.publications.win # <ticket> - <login> - <lastname> <firstname>" >> hosts.allow
tail -1 hosts.allow

