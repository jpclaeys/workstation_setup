How to grant access to a server for a user
------------------------------------------
1. Required info:
   FULLNAME=
   USERID=     # If not provided, get the uid from the outlook address book (Alias field)
   USERNAME=  
   OPPCNAME=
   TARGETHOST=

2. Get the User identifier (UID):

# check if the user already exists
   check_if_uid_exist $USERID
# if it doesn't exist, then get the first free uid
   get_first_free_uid

------------------------------------------------------------------------------------------------------------------------------------
# Manual way:
--------------
go to infrak2-pk
   - cd /applications/explo/data/opappexplo/latest
   - check if the userid already exists: 
   - grep -i <userid> */host/etc/passwd
   - if the user doesn't exist, then get first free uid
   - egrep . */host/etc/passwd| awk -F":" '$5 ~ /10/ {print $4,$5,$2}'| awk '($2=10) && ($1>81935) {print $1}'| sort -u | head -20
------------------------------------------------------------------------------------------------------------------------------------

3. go to the Target Host where the access is requested.
----------------------------------------------------------
3.1. Create the new local user
-------------------------------
{
FULLNAME=""
USERNAME=
USERID=
GROUPID=10     # staff
HOMEDIR=/export/home/$USERNAME && SHELL=/usr/bin/bash
echo "/usr/sbin/useradd -g $GROUPID -u $USERID -s $SHELL -c \"$FULLNAME\" -d $HOMEDIR  $USERNAME"
}

3.2 Create the home dir
-----------------------
echo "[ ! -d $HOMEDIR ] && mkdir $HOMEDIR && chown $USERID:$GROUPID $HOMEDIR && ls -ld $HOMEDIR"

3.3 Change the password
------------------------
DATE=`date "+%Y%m%d"`
PASSWORD=$USERID$DATE && echo $PASSWORD
passwd $USERID
New Password: $PASSWORD

3.4 Check that we can connect with the userid
----------------------------------------------
ssh 0 -l $USERID

3.5 Force user to change his password at first login
-----------------------------------------------------
passwd -x0 $USERID

3.6 Send a mail to the requester to inform him about his username/passord and ask him for his OPPC's name
----------------------------------------------------------------------------------------------------------
echo "
Dear,

Your account has been created on $TARGETHOST:

Username: $USERID
Password: $PASSWORD

You will need to change your password at the first login.

Can you provide us your PC name in order to grant you access to the server ?
"

4. Add entry to /etc/hosts.allow file
--------------------------------------

Entry:  sshd:<oppc name>.publications.win # <userid>

go to target host
cd /etc
ls -l hosts.allow
TIMESTAMP=`date "+%Y%m%d"`
cp hosts.allow hosts.allow.$TIMESTAMP
echo "sshd:$OPPCNAME.publications.win # $USERID" >> hosts.allow
tail -1 hosts.allow

----------------------------------------------------------------------------------------------------------------------------------

5. Resolve the ticket.
-----------------------
