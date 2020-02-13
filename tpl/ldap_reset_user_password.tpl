# reset a user password to it's login
--------------------------------------

# Set the LDAP admin password so it is not plaintext and not in .bash_history
read -p "Enter the password for the LDAP administrator: " LDAPPWD

0pocE123!!

login=<login>
NEWPASSWD=`perl -e  'print crypt('${login}', '${login}')'` && echo $NEWPASSWD

# check new password
ldapsearchuserpasswd $login

{
ldap_server=ldapa-pk
bind_dn="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"
ldapmodify -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: uid=${login},ou=People,dc=opoce,dc=cec,dc=eu,dc=int
changetype: modify
replace: userPassword
userPassword: {CRYPT}$NEWPASSWD
EOT
}

# check new password
ldapsearchuserpasswd $login

# Check ssh
ssh $login@0


------------------------------------------------------------------------------------------------------------------------------------

