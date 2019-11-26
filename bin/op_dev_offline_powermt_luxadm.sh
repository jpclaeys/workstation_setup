#! /bin/sh

#
# description:
#    Check if provided device is emcpower devices.
#    If yes, remove it at EMC PowerPath level, then offline it with luxadm command.
#

dev=$1
powermt_cmd=/etc/powermt
luxadm_cmd=/usr/sbin/luxadm



$powermt_cmd check dev=$dev >/dev/null
if [[ $? != 0 ]]; then
	echo "This device seems to don't exist: $dev"
	exit 12
else
	emcpower=`$powermt_cmd display dev=$dev | grep '^Pseudo name' | awk -F'=' '{print $2}'`
	echo $powermt_cmd remove dev=$emcpower
	$powermt_cmd display dev=$emcpower | grep ' alive ' | awk '{print var" -e offline /dev/rdsk/"$3}' var="$luxadm_cmd" | sed -e 's/s0$/s2/'
fi

exit 0


