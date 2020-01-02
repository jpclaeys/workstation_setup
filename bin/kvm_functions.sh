alias kvm_clusters='cat ~/doc/kvm_clusters.txt'
# Clusters KVM
alias kvmcl='echo voyager tng noblegases'
alias voyager='echo chakotay tuvok janeway torres'
alias alogens='echo fluorine bromine iodine chlorine'
alias tng='echo laforge worf picard riker'
alias metals='echo titanium chromium vanadium palladium'
alias noblegases='echo argon xenon neon krypton'
alias kvmclandhosts='for i in `kvmcl`; do printf "%-12s: " $i ; eval $i;done'
alias kvmhosts='for i in `kvmcl`; do eval $i;done|xargs'

function myterminatorkvmcluster ()
{
if [ $# -eq 0 ]; then
   errmsg "Please provide clustername"
   return 1
fi
nohup terminator --geometry=1280x800 -l $1 -T "$1" &
}

function check_kvm_multipath ()
{
[ -z "$mypasswd" ] && definemypasswd
CMD="/home/claeyje/bin/check-multipath.pl"
for H in `kvmhosts`; do msggreen "$H" && sre $H $CMD | grep -v '[47]\/4' | egrep -v "^exit|$CMD" ;done
}

function kvmclcmd ()
{
# send command to one host of a kvm cluster
h=$1
shift
sre $h $@
}

function kvmallclcmd ()
{
# send command to one node on all kvm clusters
for cl in `kvmcl`; do msggreen "$cl: " && h=`eval $cl | cut -d" " -f4`  && kvmclcmd $h $@ ;done
}

function kvmdisabledvms ()
{
kvmallclcmd "pcs status | grep Virtual | grep disabled"
}

function kvmstoppedvms ()
{
kvmallclcmd "pcs status | grep Virtual | grep Stopped"
}

function kvmlistvms ()
{
[ -z "$mypasswd" ] && definemypasswd
kvmallclcmd "pcs status | grep Virtual"
}

function kvmlistvmsandcluster ()
{
[ -z "$mypasswd" ] && definemypasswd
# send command to one node on all kvm clusters
#for cl in `kvmcl`; do msggreen "$cl: " && h=`eval $cl | cut -d" " -f4`  && sre $h "pcs status | grep Virtual | sed 's/^./$cl: /'" ;done
for cl in `kvmcl`; do msggreen "$cl: " && h=`eval $cl | cut -d" " -f4` && sre $h "pcs status" | grep Virtual | sed "s/^./$cl: /;s/, /,/"|awk '{printf "%-16s %-24s %-12s %-s\n", $1, $2, $4,$5}'; done
}

function kvmlistvmsstoppedandcluster ()
{
[ -z "$mypasswd" ] && definemypasswd
# send command to one node on all kvm clusters
#for cl in `kvmcl`; do msggreen "$cl: " && h=`eval $cl | cut -d" " -f4`  && sre $h "pcs status | grep Virtual | grep -i stopped | sed 's/^./$cl: /'" ;done
for cl in `kvmcl`; do msggreen "$cl: " && h=`eval $cl | cut -d" " -f4` && sre $h "pcs status" | grep Virtual | grep -i stopped | sed "s/^./$cl: /;s/, /,/"|awk '{printf "%-16s %-24s %-12s %-s\n", $1, $2, $4,$5}'; done
}

function kvmlistvmsstartedandcluster ()
{
[ -z "$mypasswd" ] && definemypasswd
# send command to one node on all kvm clusters
#for cl in `kvmcl`; do msggreen "$cl: " && h=`eval $cl | cut -d" " -f4`  && sre $h "pcs status | grep Virtual | grep -i started | sed 's/^./$cl: /'" ;done
for cl in `kvmcl`; do msggreen "$cl: " && h=`eval $cl | cut -d" " -f4` && sre $h "pcs status" | grep Virtual | grep -i started | sed "s/^./$cl: /;s/, /,/"|awk '{printf "%-16s %-24s %-12s %-s\n", $1, $2, $4,$5}'; done
}

