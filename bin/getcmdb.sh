#!/bin/ksh

PATH="${PATH}:/usr/sfw/bin"
export PATH

case $1 in
        opsrv|OPSRV)
        	wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=6" 2>/dev/null
        ;;
        zone|ZONE)
        	wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=26" 2>/dev/null
        ;;
        cons|CONS)
        	wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=28" 2>/dev/null
        ;;
	host|HOST)
		wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=35" 2>/dev/null
	;;
	oracle|ORACLE)
		wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=21" 2>/dev/null
	;;
        bootdisk|BOOTDISK)
                wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=44" 2>/dev/null
	;;
	linux|LINUX)
		wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=65" 2>/dev/null
	;;
	linuxvm|LINUXVM)
		wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=76" 2>/dev/null
	;;
	serial|SERIAL)
		wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=41" 2>/dev/null
	;;
	rg|RG)
                wget -O - -nv --no-proxy "http://opsvc232:8181/modules/mpirequester/lists.php?id=51" 2>/dev/null
        ;;
	*)
		echo "usage: getcmdb.sh [opsrv | zone | cons | host | oracle | bootdisk | linux | linuxvm | serial | rg ]"
	;;
esac
