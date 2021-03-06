How to add solaris roles to an INT TEST user
---------------------------------------------

# define a reference user: Philippe pierron: pierrph
# -----------------------------------------------------
REFUSER=pierrph
# Define the new user
# --------------------
NEWUSER=
TICKET=

# The implementation depends on the Solaris version:
-----------------------------------------------------
Solaris 10: (on demand only) 
-----------------------------
edit /etc/user_attr directly on demand or trigger the add_user_in_user_attr task in cfengine and wait for the next cfengine run.

Solaris 11:
-----------
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
git commit -am "$TICKET - JPC - Add entry for $NEWUSER to user_attr.d/OPinttest files"
git push
git status

##### test on the puppet client, checking out from the DEVELOPMENT branch
# Find a Solaris 11 test zone:
for Z in `zonesnoprod| grep -v SUCCESS`; do s $Z uname -rn;done | grep 11
opgtwint-tz 5.11
ceresng-tz 5.11

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


