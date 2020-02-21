Delete ldap user cmds template
--------------------------------

# Set the LDAP admin password so it is not plaintext and not in .bash_history 
read -p "Enter the password for the LDAP administrator: " LDAPPWD
0pocE123!!
USERLOGIN=<login>

getent passwd <login>
id <login>

1.2.2 definitions
------------------
# On one of the PROD LDAP servers (ldapa-pk or ldapb-pk), do :

{
export LDAPSERVER=ldapa-pk
export BINDDN="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"
}

# Check the defined variables
------------------------------
{
echo "
LDAPSERVER=$LDAPSERVER
BINDDN=$BINDDN
USERLOGIN=<login>
"
}

# Get the user groups
----------------------
echo <login>
UG=`ldapsearch -x -h $LDAPSERVER -b 'ou=group,dc=opoce,dc=cec,dc=eu,dc=int' memberuid=<login> 2> /dev/null | awk '/cn:/ {print $NF}' | sort ` && echo $UG

# Remove the user from the groups
----------------------------------
{
for group in $UG
do
ldapmodify -w $LDAPPWD -D "$BINDDN" -h $LDAPSERVER -p 389 <<EOT
dn: cn=$group,ou=group,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
delete: memberUid
memberUid: <login>
EOT
done
}

# Remove the user from the wiki
--------------------------------
{
ldapsearch -x -h $LDAPSERVER -b 'cn=user,ou=wiki,dc=opoce,dc=cec,dc=eu,dc=int' memberuid | grep -q <login>
if [ $? -eq 0 ]; then
ldapmodify -w $LDAPPWD -D "$BINDDN" -h $LDAPSERVER -p 389 <<EOT
dn: cn=user,ou=wiki,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
delete: memberUid
memberUid: <login>
EOT
fi
}

# Check that the user has been removed from all groups
-------------------------------------------------------
F="uid=<login>,ou=people,dc=opoce,dc=cec,dc=eu,dc=int"
ldapsearch -x -h $LDAPSERVER -b 'dc=opoce,dc=cec,dc=eu,dc=int' "(|(memberuid=<login>)(uniquemember="$F")(member=$F))" cn | awk '/cn:/ {print $NF}' | sort | xargs
 OR
id <login>


====================================================================================================================================

You cannot delete an entry that has children. The LDAP protocol forbids the situation where child entries would no longer have a parent.
For example, you cannot delete an organizational unit entry unless you have first deleted all entries that belong to the organizational unit.

====================================================================================================================================

Manual delete via the gui for:

- autohome (automountMapName)
- email alias (alias)
- user (People)

====================================================================================================================================

1.2.3 Delete the HOME of the user
----------------------------------
Elect one of the LDAP server to store the HOME of the user. It is either ladpa-pk or ldapb-pk. 
On one of these servers, you should run as root:

{
cd /net/nfs-infra.isilon.opoce.cec.eu.int/home
ll -d <login>
du -hs <login>
\rm -rf <login>
ll -d <login>
id <login>
}

