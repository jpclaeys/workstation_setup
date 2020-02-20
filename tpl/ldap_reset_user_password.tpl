# reset a user password to it's LOGIN
--------------------------------------

# Set the LDAP admin password so it is not plaintext and not in .bash_history
read -p "Enter the password for the LDAP administrator: " LDAPPWD

0pocE123!!

LOGIN=<login>
NEWPASSWD=`perl -e  'print crypt('${LOGIN}', '${LOGIN}')'` && echo $NEWPASSWD

# check current password
ldapsearchuserpasswd $LOGIN

{
ldap_server=$LDAPSERVER
bind_dn="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"
ldapmodify -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: uid=${LOGIN},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
replace: userPassword
userPassword: {CRYPT}$NEWPASSWD
EOT
}

# check new password
ldapsearchuserpasswd $LOGIN

# Check ssh
ssh $LOGIN@0


------------------------------------------------------------------------------------------------------------------------------------

