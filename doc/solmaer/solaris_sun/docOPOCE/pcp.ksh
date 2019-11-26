#!/usr/bin/ksh
#
# PCP (PID con Port)
# v1.08 30/12/2008 sam@unix.ms
#
# If you have a Solaris 8, 9 or 10 box and you can't
# install lsof, try this. It maps PIDS to ports and vice versa.
# It also shows you which peers are connected on which port.
# Wildcards are accepted for -p and -P options.
#
# Many thanks Daniel Trinkle trinkle@cs.purdue.edu
# for the improvements!
i=0
while getopts :p:P:a opt
do
case "${opt}" in
p ) port="${OPTARG}";i=3;;
P ) pid="${OPTARG}";i=3;;
a ) all=all;i=2;;
esac
done
if [ $OPTIND != $i ]
then
echo >&2 "usage: $0 [-p PORT] [-P PID] [-a] (Wildcards OK) "
exit 1
fi
shift `expr $OPTIND - 1`
if [ "$port" ]
then
# Enter the port number, get the PID
#
port=${OPTARG}
echo "PID\tProcess Name and Port"
echo "_________________________________________________________"
for proc in `ptree -a | awk '/ptree/ {next} {print $1};'`
do
result=`pfiles $proc 2> /dev/null| egrep "port: $port$"`
if [ ! -z "$result" ]
then
program=`ps -fo comm= -p $proc`
echo "$proc\t$program\t$port\n$result"
echo "_________________________________________________________"
fi
done
elif [ "$pid" ]
then
# Enter the PID, get the port
#
pid=$OPTARG
# Print out the information
echo "PID\tProcess Name and Port"
echo "_________________________________________________________"
for proc in `ptree -a | awk '/ptree/ {next} $1 ~ /^'"$pid"'$/ {print $1};'`
do
result=`pfiles $proc 2> /dev/null| egrep port:`
if [ ! -z "$result" ]
then
program=`ps -fo comm= -p $proc`
echo "$proc\t$program\n$result"
echo "_________________________________________________________"
fi
done
elif [ $all ]
then
# Show all PIDs, Ports and Peers
#
echo "PID\tProcess Name and Port"
echo "_________________________________________________________"
for proc in `ptree -a | sort -n | awk '/ptree/ {next} {print $1};'`
do
out=`pfiles $proc 2>/dev/null| egrep "port:"`
if [ ! -z "$out" ]
then
name=`ps -fo comm= -p $proc`
echo "$proc\t$name\n$out"
echo "_________________________________________________________"
fi
done
fi
exit 0
