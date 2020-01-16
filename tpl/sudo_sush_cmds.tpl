----------------------------------------------------------------------------------------------------
sudo_sush_cmds.tpl
----------------------------------------------------------------------------------------------------
Adding entries to the sudoers configuration (howto sudo sush)
-------------------------------------------------------------

Cfr. url: https://intragate.ec.europa.eu/publications/opitwiki/doku.php?id=op:linux:howto_sudo_sush

Locate the right file for adding a new entry
---------------------------------------------
sudo configuration files are distributed with puppet.
They can be found in your GIT repository at modules/applications/files/RedHat/etc/sudoers.d:

$ ls modules/applications/files/RedHat/etc/sudoers.d

----------------------------------------------------------------------------------------------------
====================================================================================================================================
Git: HowTo update files @ OPOCE
------------------------------------------------------------------------------------------------------------------------------------
##### from local repository, get the last version
#cd ~/git/{Linux|Solaris}/development && git branch

cd ${GIT_REPOS}/`s <hostname> uname -s`/development
cd modules/applications/files/RedHat/etc/sudoers.d
git branch 
git pull

##### update file
ll *<hostname>*
# Add entries to the appropriate file:
# ex. 
# FILE=50-cellarbo.prod
# echo -e "ferrfla LOCAL=(cellar) NOPASSWD: ALL\nferrfla LOCAL=(w_cellar) NOPASSWD: ALL" >> $FILE && cat $FILE

##### from local repository, push configuration to puppet server in developement branch
# git add <path to file>
git commit -am "<ticket> - JPC - <comment>"
git push

##### test on the puppet client, checking out from the DEVELOPMENT branch (need to be root !)
sr <hostname>
puppet agent -t --noop -o --environment  development

##### if all looks good, commit from DEVELOPMENT into PRODUCTION branch
# Go into your production repository
for OS in Solaris Linux; do grep -q ${OS} <<< $(pwd) && cd $HOME/git/${OS}/production && pwd && git branch;done

# Sync development into production
git pull origin production && git pull --no-ff

# Push your local production repository to the remote production repository
{
grep -q Solaris <<< $(pwd) && git push
grep -q Linux   <<< $(pwd) && git push origin production
}

##### goto the client and apply the changes 
sr <hostname>
puppet agent -t --noop
cd /etc/sudoers.d
# Check the content of the modified file
cat <path to file>

# Check the sudo rights
sudo -U <login> -l

su - <login>
sush <alternate user>

------------------------------------------------------------------------------------------------------------------------------------
Resolution:
------------

The sush permissions have been granted to <login> as requested:


Note:
The user <login> has to login again in order to get his new access rights.

------------------------------------------------------------------------------------------------------------------------------------

