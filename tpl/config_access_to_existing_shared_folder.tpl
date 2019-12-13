Configure access to existing shared folder
-------------------------------------------

--> Add user to samba share.
-----------------------------


1. Required info:
   FULLNAME=
   USERID=
   USERNAME=   # If not provided, get the username from the outlook address book (Alias field)
   TARGETHOST=

2. Get the User identifier (UID):

# check if the user already exists
   check_if_uid_exist $USERID
# if it doesn't exist, then get the first free uid
   get_first_free_uid


3. Go to the Target Host where the share needs to be modified.
---------------------------------------------------------------

3.1. For Solaris, create the new local user if it doesn't exist yet.
---------------------------------------------------------------------
{
FULLNAME=""
USERNAME=
USERID=
GROUPID=10
HOMEDIR=/var/empty
SHELL=/bin/false
echo "/usr/sbin/useradd -g $GROUPID -u $USERID -s $SHELL -c \"$FULLNAME\" -d $HOMEDIR  $USERNAME"
}

3.2 Check that /var/empty is present
-------------------------------------
[ ! -d /var/empty ] && mkdir /var/empty && ls -ld /var/empty

3.2 For linux, no need to create a local account
-------------------------------------------------

Check that the Windows Bind knows the userid:

wbinfo -i $USERID


4. Update the samba config file
--------------------------------

4.1 Find the samba config file
-------------------------------

smbd -b| grep CONFIGFILE

Get the included file if any.

# On linux VM's
----------------
--------------------------------------------------------------
ex on linux vm orvmwscrsng1:
[root@orvmwscrsng1 samba]# smbd -b| grep CONFIGFILE
   CONFIGFILE: /etc/samba/smb.conf
[root@orvmwscrsng1 samba]# grep include  /etc/samba/smb.conf
    include = /etc/samba/smb.conf.local

--> file to edit: /etc/samba/smb.conf.local
--------------------------------------------------------------

# Add a comma separated users list to the "write list"


4.2 On Solaris
-------------
4.2.1. Case config file in /opt/OPsamba3/users/system/samba-instance/etc/smb.conf

ps -ef | grep smbd

pargs <smbd pid> 
--> get the samba config file.

PID=`ps -ef | grep smbd| grep -v grep | awk '{print $2;exit}'` && CONFIGFILE=`pargs $PID | awk '/conf/ {print $NF}'` && echo $CONFIGFILE

[root@metaconv-dz /]# PID=`ps -ef | grep smbd| grep -v grep | awk '{print $2;exit}'` && CONFIGFILE=`pargs $PID | awk '/conf/ {print $NF}'` && echo $CONFIGFIL 
/opt/OPsamba3/users/system/samba-instance/etc/smb.conf


Add the "space separated users" list to the "valid users" list

4.2.2. case config file is on /etc/samba/samba.conf

[root@ceresng-tz /]# pargs 29177
29177:  /usr/sbin/smbd -D
argv[0]: /usr/sbin/smbd
argv[1]: -D

[root@ceresng-tz /]# smbd -b| grep CONFIGFILE
   CONFIGFILE: /etc/samba/smb.conf
[root@ceresng-tz /]# grep include /etc/samba/smb.conf
include = /etc/samba/smb_ceresng.conf


Add the "space separated users" list to the "valid users" list



5.1 Send a mail to the requester to inform him he can connect to the share:
\\<server fqdn>\share_name


