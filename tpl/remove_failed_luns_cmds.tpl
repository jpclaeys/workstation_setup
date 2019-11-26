# Cleanup failed/faulty LUNs

====================================================================================================================================
### On a kvm cluster
---------------------
# Check if there are failed/faulty LUNs
pvs

# Cleanup the failed/faulty luns 
for LUN in `pvs | grep -v p1 |  awk '{print $4}' | uniq`; do /home/admin/bin/removelun_rhel $LUN | bash ;done

# Post check
pvs
multipath -ll | egrep -i "failed|faulty" -B3 | egrep 'EMC|HITACHI' | sort

# Run Centreon check script
/etc/snmp/scripts/check_multipath.pl

====================================================================================================================================
### On stand alone hosts
------------------------
# Pre check
multipath -ll | egrep -i "failed|faulty" -B3 | egrep 'EMC|HITACHI' | sort

# Cleanup the faulty luns
for LUN in `multipath -ll | egrep -i "failed|faulty" -B3 | egrep 'EMC|HITACHI' | sort | cut -d" " -f1`; do echo /home/admin/bin/removelun_rhel $LUN;done
for LUN in `multipath -ll | egrep -i "failed|faulty" -B3 | egrep 'EMC|HITACHI' | sort | cut -d" " -f1`; do  /home/admin/bin/removelun_rhel $LUN | bash ;done

# Post check
multipath -ll | egrep -i "failed|faulty" -B3 | egrep 'EMC|HITACHI' | sort

# Run Centreon check script
/etc/snmp/scripts/check_multipath.pl

====================================================================================================================================

