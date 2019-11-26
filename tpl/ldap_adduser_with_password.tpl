
4.8.1.2.1. Add a User with a Password
To add a user with a password to the system, along with a unique group for that user:

Login to the LDAP server as root.

Use the slappasswd command to generate a password hash for a user.

Edit the /root/ldifs/add_user_with_password.ldif shown below.

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
shadowMax: 180
shadowMin: 1
shadowWarning: 7
shadowLastChange: 10701
sshPublicKey: <some SSH public key>
loginShell: /bin/bash
uidNumber: <some UID number above 1000>
gidNumber: <GID number from above>
homeDirectory: /home/<username>
userPassword: <slappasswd generated SSHA hash>
pwdReset: TRUE
Type the following, substituting your DN information for dc=your,dc=domain:

# ldapadd -Z -x -W -D "cn=LDAPAdmin,ou=People,dc=your,dc=domain" \
  -f /root/ldifs/add_user_with_password.ldif
Ensure that an administrative account is created as soon as the SIMP system has been properly configured. Administrative accounts should belong to the administrators LDAP group (gidNumber 700). By default, Members of this group can directly access a privileged shell via sudo su -.

Note

The pwdReset: TRUE command causes the user to change the assigned password at the next login. This command is useful to pre-generate the password first and change it at a later time.

This command appears to be broken in some versions of nss_ldap. Therefore, to avoid future issues set shadowLastChange to a value around 10000.

Warning

The initial password set for a user must conform to the password policy or the user will not be able to login and change his/her password, even though the password reset has been enabled by pwdReset: TRUE.

