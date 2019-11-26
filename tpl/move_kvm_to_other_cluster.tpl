Migrate a vm from one KVM cluster to another one
-------------------------------------------------

Open a ticket to the storage to map the disks to the new cluster
-----------------------------------------------------------------

Wait on the zoning


VM_NAME=
OLD_CLUSTER=
NEW_CLUSTER=

1. Check that the required vlans are defined on the new cluster
----------------------------------------------------------------
# goto one host on the old cluster (it's even better to chack on the 4 hosts of the cluster)
# identify the vlans (bridges) on the old and new clusters

ll /etc/sysconfig/network-scripts/ifcfg-br*

# If some vlan(s) are missing, then open a ticket to the network team

# When all vlans are available on the new cluster, then proceed

# Check which vlans are used by the vm to be moved: fedorafs1-recover-tk

# grep br /etc/libvirt/qemu/$VM_NAME | grep -v interface

------------------------------------------------------------------------------------------------------------------------------------
# Copy the multipath config from the old to the new cluster ; MER to MER & EUFO to EUFO
------------------------------------------------------------------------------------------------------------------------------------
# On one MER and one EUFO hosts on the old cluster, extract the vm's multipath config

VM_NAME=

multipath -ll| grep $VM_NAME
multipath -ll| grep -c $VM_NAME

# extract the vm's multipath config

mpconfinfo=/var/tmp/mpconfinfo_`uname -n`.txt && echo $mpconfinfo
grep -B2 -A2 $VM_NAME  /etc/multipath.conf | tee $mpconfinfo
OR
goto personal workstation
--------------------------
VM_NAME=
OLD_CLUSTER=
for H in $OLD_CLUSTER; do msg $H; s $H '(grep -B2 -A2 '$VM_NAME' /etc/multipath.conf | grep -v "^-")' > mp_${H}_${VM_NAME}.conf;done

# On the 4 hosts on the new cluster, update the multipath.conf file
--------------------------------------------------------------------

MER : ...060...  (ex. cluster metals: titanium chromium)
EUFO: ...069...  (ex. cluster metals: vanadium palladium)

# Make a backup of the current multipath.conf file

TIMESTAMP=`date "+%Y%m%d"`

cd /etc
cp multipath.conf multipath.conf.$TIMESTAMP

grep -c "006[09]" multipath.conf
vi multipath.conf
... add MER or EUFO entries
grep -c "006[09]" multipath.conf
# Validate the file syntax
multipath -d -v 2

# once the 4 hosts have been updagred, rscan the scsi bus for the newly added
(Cfr. wiki https://intragate.ec.europa.eu/publications/opitwiki/doku.php?id=op:linux:kvm:change_disk)

# check the mpath entries before scan (there should be none)
multipath -ll | grep -c mpath
# rescan the scsi bus
for DEVICE in `ls /sys/class/scsi_host/host?/scan`; do echo "- - -" > $DEVICE; done
# check the mpath entries after scan (there should be one entry per new disk)
multipath -ll | grep -c mpath


# On the 4 hosts of the new cluster, Reload the multipath config in order to define the aliases, and drop the "mpathxx"
-------------------------------------------------------------------------------------------------------------------------

multipath -r
multipath -ll | grep  -c mpath      # should be 0
multipath -ll | grep -c $VM_NAME    # should be equal to the nb of disks

# in case of extra LUN present, make sure it is justified.
-----------------------------------------------------------
# if not, remove the LUN

# ex. /home/admin/bin/removelun_rhel 360000970000296700069533030313039 | bash
multipath -r
multipath -ll | grep -c mpath



------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
# Create the vm xml file on one node on the target cluster, and check that the vm can be started
(Cfr. wiki: https://intragate.ec.europa.eu/publications/opitwiki/doku.php?id=op:linux:rhel:cluster_installation_rh7  ; section migration; starting at /etc/hosts.allow
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

# On the target host of the target cluster, add the MER host from which we will copy the vm wml file
------------------------------------------------------------------------------------------------------
# Modify /etc/hosts.allow to allow sshd for cluster nodes to migrate (tcp_wrappers)
# grep ^sshd /etc/hosts.allow

cp /etc/hosts.allow /etc/hosts.allow.bak_<date>
vi /etc/hosts.allow


# On the source host, copy the vm xml file
-------------------------------------------

VM_NAME="fedorafs1-recover-tk"
TARGET_NODE=titanium
echo virsh -c qemu+ssh://${TARGET_NODE}/system define /etc/libvirt/qemu/$VM_NAME.xml

# When prompted for the root password, enter the classic one (...7in)

ex.
[root@picard ~]# VM_NAME="fedorafs1-recover-tk"
[root@picard ~]# TARGET_NODE=titanium
[root@picard ~]# echo virsh -c qemu+ssh://${TARGET_NODE}/system define /etc/libvirt/qemu/$VM_NAME.xml
virsh -c qemu+ssh://titanium/system define /etc/libvirt/qemu/fedorafs1-recover-tk.xml
[root@picard ~]# echo virsh -c qemu+ssh://${TARGET_NODE}/system define /etc/libvirt/qemu/$VM_NAME.xml | bash
The authenticity of host 'titanium (10.199.99.34)' can't be established.
RSA key fingerprint is 49:54:b7:f1:af:56:2c:06:d6:a4:1a:c7:90:45:da:fd.
Are you sure you want to continue connecting (yes/no)? yes
root@titanium's password:      <--- linux pwd (...7in)
Domain fedorafs1-recover-tk defined from /etc/libvirt/qemu/fedorafs1-recover-tk.xml



# On the target host, Check if VM is defined
---------------------------------------------
virsh list --all
VM_NAME=
virsh dumpxml $VM_NAME
<snip>


# Modify cpu settings
----------------------
  <cpu mode='custom' match='exact' check='full'>
    <model fallback='forbid'>IvyBridge-IBRS</model>
    <feature policy='require' name='hypervisor'/>
    <feature policy='require' name='xsaveopt'/>
  </cpu>

# Modify network interfaces in the VM definition
-------------------------------------------------

The "source bridge" entries should reflect the vlan
ec. 
<source bridge='br227'/>
<source bridge='brbkp'/>

# Check if the disk paths are correct (on the 4 cluster hosts)
---------------------------------------------------------------
# virsh dumpxml $VM_NAME | grep "source dev" | awk -F "'" '{print $2}' | xargs ls -l

# If the guest is a RHEL 7, change the machine type: pc-i440fx-rhel7.0.0
# virsh edit $VM_NAME
# diff /tmp/ldapa-tk.xml /tmp/ldapa-tk.xml.V2
8c8
<     <type arch='x86_64' machine='rhel6.6.0'>hvm</type>
---
>     <type arch='x86_64' machine='pc-i440fx-rhel7.0.0'>hvm</type>


# push the vm config on the three other nodes of the cluster
-------------------------------------------------------------
for node in `crm_node -p | sed "s/$(hostname -s)-cl//g"`; do echo -n "$node: " && virsh -c qemu+ssh://$node/system define /etc/libvirt/qemu/$VM_NAME.xml; done

ex. 
[root@titanium etc]# for node in `crm_node -p | sed "s/$(hostname -s)-cl//g"`; do echo -n "$node: " && virsh -c qemu+ssh://$node/system define /etc/libvirt/qemu/$VM_NAME.xml; done
chromium-cl: Domain fedorafs1-recover-tk defined from /etc/libvirt/qemu/fedorafs1-recover-tk.xml
vanadium-cl: Domain fedorafs1-recover-tk defined from /etc/libvirt/qemu/fedorafs1-recover-tk.xml
palladium-cl: Domain fedorafs1-recover-tk defined from /etc/libvirt/qemu/fedorafs1-recover-tk.xml


# Cold migration, libvirt compatibility problem. Disable the VM
-----------------------------------------------------------------
# On source node
# pcs resource disable $VM_NAME

VM_NAME=
pcs constraint show location $VM_NAME
pcs status | grep $VM_NAME
# When the VM is stopped, unmanage the VM on the source cluster
----------------------------------------------------------------
pcs resource unmanage $VM_NAME
pcs status | grep $VM_NAME
 
# In case of problem, destroy the resource (makes a power-off on the vm), and then cleanup
-------------------------------------------------------------------------------------------
virsh destroy $VM_NAME
pcs resource cleanup $VM_NAME


# On target cluster check that the disks are RW
-------------------------------------------------

VM_NAME=
symdg show $VM_NAME | egrep 'Group (Name:|Type)|(RDF|Pair) State'
symdg show $VM_NAME | egrep 'Group (Name:|Type)|(RDF|Pair) State|DEV0'

ex.
[root@vanadium etc]# VM_NAME=fedorafs1-recover-tk
[root@vanadium etc]# symdg show $VM_NAME | egrep 'Group (Name:|Type)|(RDF|Pair) State'
Group Name:  fedorafs1-recover-tk
    Group Type                                   : ANY     (RDFA)
        Device RDF State                       : Ready           (RW)
        Remote Device RDF State                : Write Disabled  (WD)
        RDF Pair State (  R1 <===> R2 )        : Synchronized

# On target node, add the resource to the cluster
--------------------------------------------------
# pcs resource create ${VM_NAME} ocf:heartbeat:VirtualDomain config=/etc/libvirt/qemu/${VM_NAME}.xml migration_transport=ssh meta allow-migrate="true" --disabled

# Add location constraint tell the server to contain the vm on the site where the SAN disk is in RW mode.
# This is an example of the constraint location :

# pcs constraint location ${VM_NAME} prefers vanadium-cl=100
# pcs constraint location ${VM_NAME} prefers palladium-cl=50
# pcs resource enable ${VM_NAME}

VM_NAME=
PREFERRED1=
PREFERRED2=
pcs constraint location ${VM_NAME} prefers ${PREFERRED1}-cl=100
pcs constraint location ${VM_NAME} prefers ${PREFERRED2}-cl=50
pcs constraint show location $VM_NAME

# Check that the vm is defined
-------------------------------
virsh list --all | grep $VM_NAME

# Check the disks paths
------------------------
virsh dumpxml $VM_NAME | grep "source dev" | awk -F "'" '{print $2}' | xargs ls -l

# Try to start the vm out of the cluster management in the goal to identify the problems
-----------------------------------------------------------------------------------------

echo $VM_NAME
virsh start $VM_NAME

ex.
[root@vanadium etc]# virsh start $VM_NAME
error: Failed to start domain fedorafs1-recover-tk
error: operation failed: guest CPU doesn't match specification: missing features: rdtscp

--> edit the config file, and add the missing entry
[root@vanadium etc]# virsh edit $VM_NAME
Domain fedorafs1-recover-tk XML configuration edited.
[root@vanadium ~]# virsh dumpxml  $VM_NAME | awk '/cpu mode/,/\/cpu/'
  <cpu mode='custom' match='exact' check='full'>
    <model fallback='forbid'>IvyBridge-IBRS</model>
    <feature policy='require' name='hypervisor'/>
    <feature policy='require' name='xsaveopt'/>
    <feature policy='require' name='rdtscp'/>
  </cpu>


# Try to start the vm
----------------------

[root@vanadium etc]# virsh start $VM_NAME
Domain fedorafs1-recover-tk started

# Launch the console
---------------------
virsh console  $VM_NAME

ex.
[root@vanadium etc]# virsh console  $VM_NAME
Connected to domain fedorafs1-recover-tk
Escape character is ^]
Press any key to continue.
               Welcome to Red Hat Enterprise Linux Server
Starting udev: [  OK  ]
<snip>

# If the vm started successfully, then stop it
------------------------------------------------
virsh shutdown  $VM_NAME
virsh list --all | grep $VM_NAME

ex.
[root@vanadium etc]# virsh shutdown  $VM_NAME
Domain fedorafs1-recover-tk is being shutdown

[root@vanadium etc]# virsh list --all | grep $VM_NAME
 -     fedorafs1-recover-tk           shut off



# enable the cluster resource
------------------------------

pcs resource enable $VM_NAME
pcs status | grep  $VM_NAME


ex.
[root@vanadium etc]# pcs resource enable $VM_NAME
[root@vanadium etc]# pcs status | grep  $VM_NAME
 fedorafs1-recover-tk   (ocf::heartbeat:VirtualDomain): Started vanadium-cl

--> the vm has successfully started on the cluster

===================================================================================================================================================
# Post checks
--------------

# Connect to the vm
ssh $VM_NAME
# become root
# check lvm
pvs;vgs;lvs
# check fstab
cat /etc/fstab
df -h


===================================================================================================================================================
===================================================================================================================================================

