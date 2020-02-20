Add new ldap user cmds template
--------------------------------

Ref: https://intragate.ec.europa.eu/publications/opitwiki/doku.php?id=op:nix:howto_manage_user_accounts&#adding_a_user_account

1. Define variables
--------------------
# Get the first available uid
get_first_free_uid 30250 | grep -i First

FIRST_NAME=<firstname>
LAST_NAME=<lastname>
USERLOGIN=<login>
USERID=
GIDNUMBER=47110  # opunix

2. Add the user to ldap
------------------------
===> Usage: ldapadduser: <first_name> <last_name> <login> <uid> [-dry] [-v] [gid=] [ldap_server=] [wiki=] [official=] [system=] [int_test=] [int_prod=] [dba=] [aws_cellar=] <===

ldapadduser "$FIRST_NAME" "$LAST_NAME" $USERLOGIN $USERID -dry -v

3. Check group membership of the new user
------------------------------------------
id <login>
# Compare with another member if the same team

4. Create the HOME of the user
-------------------------------
Elect one of the LDAP server to store the HOME of the user. It is either ladpa-pk or ldapb-pk. 
On one of these servers, you should run as root:

{
cd /net/nfs-infra.isilon.opoce.cec.eu.int/home
mkdir <login>; chown <login>.$GIDNUMBER <login>; ls -ldh <login>
}

5. Puppet configuration
------------------------
For INT TEST users, update the user_attr in puppet (Cfr. add_solaris_roles_to_int_test_user.tpl)

6. Important note:
-------------------
It takes some time to populate the ldap modifications on all of the servers.

To be sure that ldap is updated on a specific server, just restart the sssd service:

# systemctl restart sssd. 


