----------------------------------------------------------------------------------------------------
# Template: delete_host_from_satellite_cmds.tpl
----------------------------------------------------------------------------------------------------

sr satellite-pk 

# If only one host:

satellite_delete_host <hostname>
# Check
satellite_host_list <hostname>

# If multiple hosts

HL=`echo "

"` && echo $HL && wc -w <<< $HL

satellite_delete_host $HL

satellite_host_list $HL

----------------------------------------------------------------------------------------------------
log:
-----

----------------------------------------------------------------------------------------------------
Resolution:
------------
Server <hostname> has been deleted from satellite as requested.

If Solaris zone:
-----------------
Server <hostname> is not configured in satellite.
No further action required.

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------



