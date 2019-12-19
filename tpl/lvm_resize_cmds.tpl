Resize online lvm on VMware Redhat
-----------------------------------
Note: fdisk is limited to 2 TB capacity !!!

1. Ask increase of storage to windows team
-------------------------------------------

2. Fetch current status
------------------------
vgs
VGNAME=
vgdisplay $VGNAME -v | egrep 'Physical|PV Name|Volume group|VG Size'

# Find the disk to extend
pvs | egrep "PV|$VGNAME"

3. Define variables
--------------------
{
DEV=<dev name>  && echo "# DEV=$DEV"   # ex. DEV=sdb 
DISK=/dev/$DEV && echo "# DISK=$DISK"
PARTITION=${DISK}1 && echo "# PARTITION=$PARTITION"
MOUNTPOINT=/applications/axway && echo "# MOUNTPOINT=$MOUNTPOINT"
LVNAME=`df -hlP | grep $MOUNTPOINT | awk '/mapper/ {print $1}'` && echo "# LVNAME=$LVNAME"
df -hTP  $MOUNTPOINT
# check the partition type (msdos or GPT)
parted $DISK print
}

4. Rescan disk 
---------------
echo "1" > /sys/class/block/${DEV}/device/rescan

OR rescan all disks
--------------------
for D in `ls /sys/class/scsi_disk/*/device/rescan`; do echo '1' > $D;done

5. Check result
----------------
tail /var/log/messages | grep kernel

OLDSIZE=`tail /var/log/messages | grep capacity | awk '{print $(NF-2)}'` && echo $OLDSIZE
NEWSIZE=`tail /var/log/messages | grep capacity | awk '{print $(NF)}'` && echo $NEWSIZE
echo "scale=2;${OLDSIZE}/1024/1024/1024" | bc
echo "scale=2;${NEWSIZE}/1024/1024/1024" | bc

6. Get disk info
-----------------
fdisk -l $DISK
If there is no partition, then skip the fdisk recreate partition table section


7. Recreate the partition table
--------------------------------
fdisk [-c=dos] $DISK
use -c flag above if first sector of partition is below 2048

# Ex.
====================================================================================================================================

[root@orvmwscndwh ~]# fdisk /dev/sdb
Welcome to fdisk (util-linux 2.23.2).

Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.


Command (m for help): p

Disk /dev/sdb: 483.2 GB, 483183820800 bytes, 943718400 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x000e0e13

   Device Boot      Start         End      Blocks   Id  System
/dev/sdb1            2048   734003199   367000576   8e  Linux LVM

Command (m for help): d
Selected partition 1
Partition 1 is deleted

Command (m for help): n
Partition type:
   p   primary (0 primary, 0 extended, 4 free)
   e   extended
Select (default p):
Using default response p
Partition number (1-4, default 1):
First sector (2048-943718399, default 2048):
Using default value 2048
Last sector, +sectors or +size{K,M,G} (2048-943718399, default 943718399):
Using default value 943718399
Partition 1 of type Linux and of size 450 GiB is set

Command (m for help): t
Selected partition 1
Hex code (type L to list all codes): 8e
Changed type of partition 'Linux' to 'Linux LVM'

Command (m for help): p

Disk /dev/sdb: 483.2 GB, 483183820800 bytes, 943718400 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x000e0e13

   Device Boot      Start         End      Blocks   Id  System
/dev/sdb1            2048   943718399   471858176   8e  Linux LVM

Command (m for help): w
The partition table has been altered!

Calling ioctl() to re-read partition table.

WARNING: Re-reading the partition table failed with error 16: Device or resource busy.
The kernel still uses the old table. The new table will be used at
the next reboot or after you run partprobe(8) or kpartx(8)
Syncing disks.

====================================================================================================================================


8. Resize the physical volume
------------------------------
# get current in-memory partition table
cat /proc/partitions | grep $DEV
# inform the OS of partition table changes
partprobe -d  # dry-run
partprobe
cat /proc/partitions | grep $DEV
lvdisplay $LVNAME | egrep "Name|Path|Size"
df -hTP $MOUNTPOINT
if there is a partition
echo pvresize $PARTITION
else
echo pvresize $DISK

pvscan
vgs

9. Extend volume and resize FS
-------------------------------
df -hTP $MOUNTPOINT
echo "lvextend -L+<extend size>G $LVNAME -r"
OR 
echo "lvextend -l+100%FREE $LVNAME -r"
If the '-r' option is omitted, the resize the FS
# resize2fs $LVNAME
df -hTP $MOUNTPOINT
lvdisplay $LVNAME | egrep "Name|Path|Size"


====================================================================================================================================

