
4.8.1.2.2. Add a User without a Password
To add a user without a password to the system, along with a unique group for that user

Login to the LDAP server as root.

Edit the /root/ldifs/add_user_no_password.ldif shown below.

dn: cn=<username>,ou=Group,dc=your,dc=domain
objectClass: posixGroup
objectClass: top
cn: <username>
gidNumber: <Unique GID Number>
description: "<Group Description>"

dn: uid=<username>,ou=People,dc=your,dc=domain
uid: <username>
cn: <username>
givenName: <First Name>
sn: <Last Name>
mail: <e-mail address>
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
objectClass: ldapPublicKey
sshPublicKey: <some SSH public key>
loginShell: /bin/bash
uidNumber: <some UID number above 1000>
gidNumber: <GID number from above>
homeDirectory: /home/<username>
Type the following, substituting your DN information for dc=your,dc=domain:

# ldapadd -Z -x -W -D "cn=LDAPAdmin,ou=People,dc=your,dc=domain" \
  -f /root/ldifs/add_user_no_password.ldif

