
# Set the LDAP admin password so it is not plaintext and not in .bash_history
read -p "Enter the password for the LDAP administrator: " LDAPPWD

0pocE123!!

{
OPPC=opdt237
export ldap_server=ldapa-pk
export bind_dn="CN=directory manager,DC=opoce,DC=cec,DC=eu,DC=int"
ldapadd -w $LDAPPWD -D "$bind_dn" -h $ldap_server -p 389 <<EOT
dn: cn=admin,ou=netgroup,dc=opoce,dc=cec,dc=eu,dc=int
cn: admin
changetype: modify
#add: nisNetgroupTriple type=normal
nisNetgroupTriple: ($OPPC,,opoce.cec.eu.int)
nisNetgroupTriple: ($OPPC.opoce.cec.eu.int,,)
nisNetgroupTriple: ($OPPC,,publications.win)
nisNetgroupTriple: ($OPPC.publications.win,,) 
objectClass: top    
objectClass: nisNetgroup    
EOT
}

ldapsearchopdt $OPPC

OPPC=opdt237

cat <<EOT
nisNetgroupTriple: ($OPPC,,opoce.cec.eu.int)
nisNetgroupTriple: ($OPPC.opoce.cec.eu.int,,)
nisNetgroupTriple: ($OPPC,,publications.win)
nisNetgroupTriple: ($OPPC.publications.win,,) 

EOT
