HowTo add an LDAP user in the OPOCE Environment
------------------------------------------------

Ex. add user brunnic that will replace the user bergale 
Ticket IM0017782364 
Description:

May I ask you to arrange 'UNIX technical account' access rights for our new team member Mr. BRUNEAU Nicolas.
He will be 50% replacing Mr. Alexander BERG (who is at the moment 50% at parental leave). All his access should be the same as for other team members (INT TEST group).

UNIX technical account
new member of INT TEST team; please give Mr. BRUNEAU the same level of access as his team colleagues (test and reception servers).
Additional info:
Affected User: BRUNNIC 
------------------------------------------------------------------------------------------------------------------------------------
Note: 
LDIF Format
LDIF, or the LDAP Data Interchange Format, is a text format for representing LDAP data and commands. 
When using an LDAP system, you will likely use the LDIF format to specify your data and the changes you wish to make to the LDAP DIT.
------------------------------------------------------------------------------------------------------------------------------------

# Define variables
#------------------
{
# SOLARISLOGINHOST must be defined in bashrc
[ "$SOLARISLOGINHOST" == "`uname -n`" ] && CMD= || CMD="s $SOLARISLOGINHOST" ; echo $CMD
NEWUSER=brunnic
NEWUSERGECOS="Nicolas BRUNEAU" && echo "$NEWUSER gecos: $NEWUSERGECOS"
NEWGID=       # define only it's different from the REFUSER
NEWUSERGECOSDOTTED=`echo $NEWUSERGECOS | sed 's/ /./'`
REFUSER=bergale
REFUSERGECOS=`$CMD ldapsearchgecos $REFUSER` # && echo "$REFUSER gecos: $REFUSERGECOS"
REFUSERGECOSDOTTED=`echo $REFUSERGECOS | sed 's/ /./'`
REFUSERUIDNB=`$CMD ldapsearchuser $REFUSER| awk '/uidNumber/ {print $NF}'` && echo "$REFUSER uidNumber: $REFUSERUIDNB"
# Get the next free uid
NEWUSERUIDNB=`get_first_free_uid $REFUSERUIDNB | tail -1| awk '{print $NF}'` && echo "$NEWUSER uidNumber: $NEWUSERUIDNB"
NEWUSERGIDNB=${NEWGID:-`$CMD ldapsearchusergidnumber $REFUSER`} && echo "$NEWUSER gidNumber: $NEWUSERGIDNB"
# Generate a password using slappasswd:
# --------------------------------------
# Encrypt password: "Opoce123"
NEWUSERPASSWD=`$CMD slappasswd -h {SSHA} -s Opoce123` && echo "$NEWUSER password: $NEWUSERPASSWD"
}

brunnic gecos: Nicolas BRUNEAU
bergale uidNumber: 30223
brunnic uidNumber: 30228
brunnic gidNumber: 47110
brunnic password: {SSHA}KgRQ4PIQJQzeWniDdGvWKwyM7lVbFa2d


Goto a Solaris server for the ldapserach commands !!!
------------------------------------------------------
1. Goto the ldap web interface (ldapa-pk)

2. Open the People branch (Alternative: ldapsearchuser $REFUSER) 
-----------------------------------------------------------------

Select the user $REFUSER
Export
Check "Save as file"
Export format: LDIF
Press "Proceed"

Show in folder
Open with Notepad++

Save as brunnic.ldif
Remove all comment lines
Replace "Alexander BERG" with "Nicolas BRUNEAU"
Replace $REFUSER with brunnic

Find a new unique uid for brunnic

Replace the uidnumber with a new one
save

Once it's ok, one can add the new user by importing the ldif file.

Press "import" on the left menu

Choose file

Proceed

Update object (twice)

Alternative:
-------------
{
separator 80 \#
$CMD ldapsearchuser $REFUSER | sed "s/$REFUSER/$NEWUSER/;s/$REFUSERGECOS/$NEWUSERGECOS/;s/$REFUSERUIDNB/$NEWUSERUIDNB/"
echo "userPassword: $NEWUSERPASSWD"
echo "pwdReset: TRUE"
separator 80 \#
}

[claeyje@kenobi ~]# {
> separator 80 \#
> $CMD ldapsearchuser $REFUSER | sed "s/$REFUSER/$NEWUSER/;s/$REFUSERGECOS/$NEWUSERGECOS/;s/$REFUSERUIDNB/$NEWUSERUIDNB/"
> echo "userPassword: $NEWUSERPASSWD"
> echo "pwdReset: TRUE"
> separator 80 \#
> }
################################################################################
dn: uid=brunnic,ou=People,dc=opoce,dc=cec,dc=eu,dc=int
loginShell: /bin/bash
uidNumber: 30228
gidNumber: 47110
shadowMax: -1
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
objectClass: top
uid: brunnic
gecos: Nicolas BRUNEAU
shadowLastChange: 0
cn: Nicolas BRUNEAU
homeDirectory: /home/brunnic
userPassword: {SSHA}KgRQ4PIQJQzeWniDdGvWKwyM7lVbFa2d
pwdReset: TRUE
################################################################################

Then Import
paste the user data
Proceed

3. LDAP: set the autohomeKey
-----------------------------

Export autohome info for $REFUSER (alternative: ldapsearchautomount $REFUSER)

Check "Save as file"
Export format: LDIF
Press "Proceed"

edit the file
Then import
Select the LDIF file or paste the LDIF in the paste area
Press "Proceed"
Update ...

Alternative:
------------

{
separator 80 \#
$CMD ldapsearchautomount $REFUSER | grep -v ^version | sed "s/$REFUSER/$NEWUSER/"
separator 80 \#
}
################################################################################
dn: automountKey=brunnic,automountMapName=auto_home,dc=opoce,dc=cec,dc=eu,dc=int
automountKey: brunnic
objectClass: automount
objectClass: top
automountInformation: -soft nfs-infra.isilon.opoce.cec.eu.int:/home/&
################################################################################
Import
paste the data
Proceed

4. Create the home dir
-----------------------

become root on opvmwstsx11
goto the isilon home 
{
echo cd /net/nfs-infra.isilon/home
echo mkdir $NEWUSER
echo chown $NEWUSER:$NEWUSERGIDNB $NEWUSER
echo ls -al $NEWUSER
echo cd /home/$NEWUSER
echo "pwd && ls -la"
}

5. Add user in the required groups
-----------------------------------
Find the required groups:
# id -a $REFUSER
OR
$CMD ldapsearchusergroups $REFUSER

[claeyje@kenobi ~]# $CMD ldapsearchusergroups $REFUSER
int_test op-t-int aws-t-int

Then, for each and every required group, add the new user ("add value") in the "memberuid" list

6. Create the mail alias in Aliases
------------------------------------

{
separator 80 \#
$CMD ldapsearchaliases $REFUSER| sed "s/$REFUSER/$NEWUSER/;s/$REFUSERGECOSDOTTED/$NEWUSERGECOSDOTTED/"
separator 80 \#
}

################################################################################
dn: cn=brunnic,ou=aliases,dc=opoce,dc=cec,dc=eu,dc=int
mail: brunnic
mgrpRFC822MailMember: Nicolas.BRUNEAU@ext.publications.europa.eu
rfc822MailMember: Nicolas.BRUNEAU@ext.publications.europa.eu
objectClass: mailGroup
objectClass: nisMailAlias
objectClass: top
cn: brunnic
################################################################################


ldap gui
import
paste the alias definition
Proceed
 
7. Set the initial password (if not yet present)
-------------------------------------------------
If it is not already present, then open the ldap dui
select the user
Press on "Add new Attribute"
Select "Passord in the dropdown menu"
Select type "SSHA"
Paste the SSHA password
Press Update Object (twice)

OR

ldap gui

Using "Changetype: Add" to Create New Entries
{
separator 80 \#
echo "dn: uid=$NEWUSER,ou=People,dc=opoce,dc=cec,dc=eu,dc=int
changetype: add
userPassword: $NEWUSERPASSWD
pwdReset: TRUE"
separator 80 \#
}

################################################################################
dn: uid=brunnic,ou=People,dc=opoce,dc=cec,dc=eu,dc=int
changetype: add
userPassword: {SSHA}KgRQ4PIQJQzeWniDdGvWKwyM7lVbFa2d
pwdReset: TRUE
################################################################################


import
paste the alias definition
Proceed

8. Adding roles to Solaris
---------------------------



Solaris 11: puppet
Solaris 10: edit /etc/user_attr directly on demand or trigger the add_user_in_user_attr task in cfengine and wait for the next cfengine run.


Puppet:
-------

cd $HOME/git/Solaris/development
# get the latest version of the dev env
git pull

# Check if the new user is already present
ATTRDIR=$HOME/git/Solaris/development/modules/applications/files/Solaris/etc/user_attr.d
grep -lc $NEWUSER $ATTRDIR/OPinttest*
# If the output ends with "1"; the the entry is already present.

# else
# Add new entry to OPinttest\* files

find . -name OPinttest\* 

[claeyje@opvmwstsx11 development]# find . -name OPinttest\* 
./modules/applications/files/Solaris/etc/user_attr.d/OPinttest.cellar.test
./modules/applications/files/Solaris/etc/user_attr.d/OPinttest.immcbuild.test
<snip>

echo "$REFUSER $NEWUSER"

ATTRDIR=$HOME/git/Solaris/development/modules/applications/files/Solaris/etc/user_attr.d
for F in `grep -l $REFUSER $ATTRDIR/OPinttest*`; do echo "#==> Adding entry to $F" && grep $REFUSER $F | sed "s/$REFUSER/$NEWUSER/" >> $F;done

# view the changes
git diff
# Commit the changes
git commit -am "JPC - Add entry for $NEWUSER to user_attr.d/OPinttest files"
git push
git status

##### test on the puppet client, checking out from the DEVELOPMENT branch
puppet agent -t --noop -o --environment  development
Note: this will only show the modifications that would apply, but doesn't actually do it because of the "noop" option


##### if all looks good, commit from DEVELOPMENT into PRODUCTION branch
cd ../production 
git pull origin production && git pull --no-ff
{
pwd | grep Solaris >/dev/null
if [[ $? == 0 ]]; then git push && cd -; fi
pwd | grep Linux >/dev/null
if [[ $? == 0 ]]; then git push origin production && cd -; fi
}

