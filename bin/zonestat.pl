#!/usr/bin/perl
close STDERR;
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at
# http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# Copyright 2008 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#
#
# zonestat: tool that displays each zone's usage of resources
#           that can be controlled.
#
# Concept, design, implementation: Jeff Victor, Sun Microsystems, Inc.
#
#  Versions:
#   1.0: Initial release
#   1.1: Group zones by resource pool, display in order of pool number
#   1.2: Provide total usage and physical capacity data, improve output precision
#   1.2.1: Various minor fixes:
#        * -h option to swap(1M) not available until S10 5/08 (GaelM)
#        * Change $update value for Solaris Nevada to 7
#        * Fixed bugs in CPU cap & FSS output
#        * Added -h (help)
#        * Added -P (easily parseable output)
#        * Inhibit command-line error messages
#
# Usage: zonestat [-l] [interval [count]]
#        -h: display usage summary
#        -l: display columns showing the configured limits
#        -P: display output in easily parseable format (assumes -l)
#
# Output (with -l):
#
#
#        |----Pool-----|------CPU-------|----------------Memory----------------|
#        |---|--Size---|-----Pset-------|---RAM---|---Shm---|---Lkd---|---VM---|
#Zonename| IT| Max| Cur| Cap|Used|Shr|S%| Cap|Used| Cap|Used| Cap|Used| Cap|Used
#-------------------------------------------------------------------------------
#  global  0D  66K    8       0.2   1 50      173M            16E    0  16E 318M
#   ozone  0D  66K    1  1.7  0.2   1 50 100M  31M  50M       30M    0 200M  26M
#   zone1  3P    4    4       0.0   1 HH 100M  44M  50M       30M    0 200M  40M
#twilight  5S    8    8  1.7  0.9  50 50 100M  54M  50M       30M    0 200M  45M
#   zone5  5S    8    8  1.7  0.9  50 50 100M  33M  50M       30M  100 200M  43M
#   zone2  6P    3    3       0.0   1 HH 100M  52M  50M       30M    0 200M  43M
#==TOTAL=            32       2.2         32G 387M                 100  48G 515M
#
# Explanation of output:
# Pool: Data about the pool in which the zone's processes run
#   IT: "ID" + "Type"
#     ID: Pool ID number, from poolstat
#     Type: Type of Pool: D=Default, P=Private ("temporary"), S=Shared
#   Size: Number of CPUs
#     Max: Configured for pool (-l)
#     Cur: Currently in pool
# CPU: Data about CPU usage or usage constraints
#   Cap: capped-cpu (-l)
#   Pset Used: amount of CPU 'power' used by the processes sharing the pset
#     in which the zone's processes run - compare to "Cap".
#   Shr: Number of FSS shares (-l)
#   S%: This zone's portion of all shares in all zones in this pool ('HH'=100) (-l)
# Memory: Data about memory usage or limits
#   RAM: Physical memory
#     Cap: capped-memory:physical (-l)
#    Used: RSS of zone
#   Shm: Shared memory
#     Cap: max-shm-memory (-l)
#    Used: amount of shared memory in use by this zone's processes
#   Lkd: Locked memory
#     Cap: capped-memory:locked (-l)
#    Used: amount of memory locked by this zone's processes
#   VM: Virtual memory
#     Cap: capped-memory:swap (-l)
#    Used: amount of virtual memory (RAM+Swap) in use by this zone's processes
# The special row marked "==TOTAL= displays a total or 'absolute maximum'
# value, depending on the object being measured, and the amount used across
# all zones, including the global zone.
#
# Problems:
#  * By far the "most broken" part of this prototype is CPU%.
#    It is not difficult to create surprising results, e.g. on a CMT system,
#    set a CPU cap on a zone in a pool, and run a few CPU-bound processes:
#    the "Pset Used" column will not reach the CPU cap.
#
# Ideas for Future:
#  * Add -c: list zones that are configured, even if halted (like 'zoneadm list -c')
#  * Add -d: also display disk statistics (fsstat?)
#  * Add -n: also display network statistics
#  * Add -p: only show processor info, but show more, including:
#    * prstat's instantaneous CPU%, micro-state fields *and* mpstat's
#      CPU% during a sample
#    * scheduler used for the pset in which the zone resides
#    * queue length for the pset in which that zone resides
#  * Add '-m': only show memory-related info for each zone and its pool,
#    adding these:
#    * paging columns of vmstat (re, mf, pi, p, fr, de, sr)
#    * output of 'vmstat -p'
#    * free swap space
#  * Add optional [<zonename>] argument to limit output to one zone
#  * Debate the inaccuracy of prstat's CPU data vs. the sample time
#    and potentially misleading data of mpstat. Then choose something better. :-)
#  * Add a one-character column showing the default scheduler for each pool.
#  * Report state transitions like mpstat does, e.g.
#    * Changes in pool configuration, new pools, deleted pools
#    * Changes in zone states: boot, halt
#  * Improve efficiency and robustness with Perl extension module Sun::Solaris::Kstat.
#    Would only help locked-memory and swap-cap until more kstats are available.
#  * Improve efficiency by re-writing in C or D.
#  * Improve robustness by handling error conditions better.

#
# Variables and arrays.
#
#  %poolid: integer ID of zone's pool - from poolstat
#  %poolmembers: list of zones in each pool
#  @poolshares: total of FSS shares in all zone of a pool
#  %psetid: integer ID of zone's pset - from poolstat
#  %ztype:   type of pool: Private, Shared, Default - derived from zonecfg
#  %pset_cfg_min: minimum CPUs configured for this pool - from zonecfg, poolstat
#  %pset_cfg_max: maximum CPUs configured for this pool - from zonecfg, poolstat
#  %pset_cur:     current CPUs configured for this pool - from poolstat
#  %cpu_cap:       CPU cap - from prctl
#  %cpu_percent:   Percent of pool in use by this zone - from mpstat
#  %cpu_shares:   FSS Shares configured - from prctl
#  %cpu_shrpercent: Portion of pool's shares in this zone - sum of zones' shares
#  $cpus_used_sum Total "CPU power" used, in CPUs
#  %rss_cap:      RAM cap - from rcapstat
#  %rss_use:      RAM used - from rcapstat if rcap enabled, prstat otherwise
#  $rss_use_sum   Total RAM used in system
#  %shm_cap:      Shared memory cap - from prctl
#  %shm_use:      Shared memory used - from ipcs
#  $shm_use_sum   Total shared memory used in system
#  @lkd_cap:      Amount of memory a zone can lock - from kstat lockedmem_zone
#  @lkd_use:      Amount of memory locked by a zone - from kstat lockedmem_zone
#  $lkd_use_sum   Total locked memory in system
#  @vm_cap:       VM cap - from kstat
#  @vm_use:       VM used - from kstat
#  $vm_use_sum   Total (RAM+swap) used in system

use Getopt::Std;

# Subroutine 'shorten' shortens integers that won't fit into 4 digits, for
# compact, predictable output columns. Example: 234,567==>234K.
# Note that 1K=1,000, not 1,024.
#
# Compute constants once.
$K=1000**1;
$M=1000**2;
$G=1000**3;
$T=1000**4;
$P=1000**5;
$E=1000**6;

#$PrintTimes=0;

sub shorten {
my $n=$_[0];
#if (!defined($n)) { $n=0; }
if ($n < 10)                 { $n = sprintf ("%1.1f", $n); }
if ($n >= 10   && $n < 1000) { $n = sprintf ("%d", $n); }
if ($n >= 1000 && $n < 9500) { $n = sprintf ("%1.1fK", $n/$K);}
if ($n >= 9500 && $n < $M) { $n = int(($n+500)/1000) . "K"; }
if ($n >= $M && $n < 9500000) { $n = sprintf ("%1.1fM", $n/$M);}
if ($n >= 9500000 && $n < $G) { $n = int(($n+500*$K)/$M) . "M"; }
if ($n >= $G && $n < 9500000000) { $n = sprintf ("%1.1fG", $n/$G);}
if ($n >= 9500000000 && $n < $T) { $n = int(($n+500*$M)/$G) . "G"; }
if ($n >= $T && $n < 9500000000000) { $n = sprintf ("%1.1fT", $n/$T); }
if ($n >= 9500000000000 && $n < $P) { $n = int(($n+500*$G)/$T) . "T"; }
if ($n >= $P && $n < 9500000000000000) { $n = sprintf ("%1.1fP", $n/$P);}
if ($n >= 9500000000000000 && $n < $E) { $n = int(($n+500*$T)/$P) . "P"; }
if ($n >= $E ) { $n = int(($n+500*$P)/$E) . "E"; }
$n=$n;
}

sub expand { # Assumes that the argument ends in a metric suffix!
my $n=$_[0];
$suffix=chop($n);
if ($suffix eq 'K' || $suffix eq 'k') {$n *= $K};
if ($suffix eq 'M' || $suffix eq 'm') {$n *= $M};
if ($suffix eq 'G' || $suffix eq 'g') {$n *= $G};
if ($suffix eq 'T' || $suffix eq 't') {$n *= $T};
if ($suffix eq 'P' || $suffix eq 'p') {$n *= $P};
if ($suffix eq 'E' || $suffix eq 'e') {$n *= $E};
$n=$n;
}

# A numeric sort subroutine.
sub numerically { $a <=> $b; }

#
# Gather static info
#
open (MEM, "/usr/sbin/prtconf |");
while (<MEM>) {
  if (/Memory size: (\d+) Megabytes/) {
    $RAM=$1*1024*1024;
  }
}
close MEM;
open (PGSZ, "/bin/pagesize|");
  $pagesize=<PGSZ>;
close PGSZ;

#
# Process the command line
#
# Options...
$opt_h=0;
$opt_l=0;
$opt_P=0;

getopts('hlP');

# ...and [interval [count]]
$decrement=1; # Change to zero (below) if infinite loop
$count=1;     # Default
$interval=0;  # sleeptime between iterations
$doheader=1;  # Display a new header after 25 lines of data.

if ($#ARGV>=0 ) {
  $interval=shift(@ARGV);
  $decrement=0;
  if ($#ARGV>=0 && $ARGV[0]>0) {
    $count=$ARGV[0];
    $decrement=1;
  }
}

# U4 added several RM features
# U5 added CPU Caps
# For U0-U3, we show what you could be doing if you upgrade... ;-)

open (RELEASE, "/etc/release");
$rel=<RELEASE>;
close RELEASE;
if ($rel =~ /3\/05/) { $update=1; }
if ($rel =~ /6\/06/) { $update=2; }
if ($rel =~ /11\/06/) { $update=3; }
if ($rel =~ /8\/07/) { $update=4; }
if ($rel =~ /5\/08/) { $update=5; }
if ($rel =~ /10\/08/) { $update=6; }
if ($rel =~ /snv/) { $update=7; }

if ($opt_h) {
  print "
 Usage: zonestat [-h] | [-l] [interval [count]]
        -h: usage information
        -l: display columns showing the configured limits

Output with -l option:
        |----Pool-----|------CPU-------|----------------Memory----------------|
        |---|--Size---|-----Pset-------|---RAM---|---Shm---|---Lkd---|---VM---|
Zonename| IT| Max| Cur| Cap|Used|Shr|S%| Cap|Used| Cap|Used| Cap|Used| Cap|Used

Pool: information about the Solaris Resource Pool to which the zone is assigned.
   I: Pool identification number for this zone's pool
   T: Type of pool: D=Default, P=Private (temporary), S=Shared
 Max: Maximum number of CPUs configured for this zone's pool
 Cur: Current number of CPUs configured for this zone's pool

CPU: information about CPU controls and usage
  Cap: CPU-cap for the zone
 Used: Amount of CPU power consumed by the zone recently
  Shr: Number of FSS shares assigned to this zone
   S%: Percentage of this pool's CPU cycles for this zone ('HH' = 100%)

Memory: information about memory controls and usage
 RAM: Physical memory information
   Cap: Maximum amount of RAM this zone can use
  Used: Amount of RAM this zone is using
 Shm: Shared memory information
   Cap: Maximum amount of shared memory this zone can use
  Used: Amount of shared memory this zone is using
 Lkd: Locked memory information
   Cap: Maximum amount of locked memory this zone can use
  Used: Amount of locked memory this zone is using
 VM: Virtual memory information
   Cap: Maximum amount of virtual memory this zone can use
  Used: Amount of virtual memory this zone is using

";
  exit;
}

#
# Outer loop
#
for ($n=$count; $n>0; $n -= $decrement) {

#
# Gather list of zones, their status and pool type and association.
open (NAMES, "/usr/sbin/zoneadm list -v|");
$znum=0;
while (<NAMES>) {
  if (/^\s+(\S+)\s+(\S+)/) {
    if ($1 eq "ID") { next; }
    $names[$znum++]=$2;
    $zoneid{$2}=$1;
  }
}
close NAMES;

# Update vCPU count.
$total_cpus=0;
open (PSR, "/usr/sbin/psrinfo |");
while (<PSR>) { $total_cpus++; }
close PSR;

# Are we using pools?
open (POOLS, "/usr/bin/svcs -H pools|");
$pools_enabled=<POOLS>;
close POOLS;

# Does rcap exist and is it enabled?
open (RCAP, "/usr/bin/svcs -H rcap|");
$rcap_enabled=<RCAP>;
close RCAP;

#
# Get pool minima, maxima, current sizes. Note that some of these
# values are stored in /etc/zones/index but do *not* reflect current
# reality. Where appropriate, those values will be updated later with
# current reality.
# Note that the data collected here will be obsolete if a zone's cfg
# is changed after the most recent boot of that zone. These commands
# should be replaced, e.g. with
# 1) "ps -eo zone,pset,comm | grep zsched"
# to collect the mapping from zone to pset ID, and then
# 2) "poolstat -r pset -o pool,rid" to complete the mapping from zonename
# to poolname.
foreach $z (@names) {
  open (ZCFG, "/usr/sbin/zonecfg -z $z info pool|");
  $_=<ZCFG>;
  if (/pool: (\S+)/) {
    $pool{$z}=$1;
    $ztype{$z}="S";
  } else {
    open (ZCFG, "/usr/sbin/zonecfg -z $z info dedicated-cpu|");
    $_=<ZCFG>;
    if (/dedic/) {
      $range=<ZCFG>;
      if ($range =~ /(\d+)-(\d+)/) {
        $pset_cfg_min{$z}=$1;
        $pset_cfg_max{$z}=$2;
      } else {
        $range =~ /(\d+)/;
        $pset_cfg_min{$z}=$1;
        $pset_cfg_max{$z}=$1;
      }
      $pool{$z}="SUNWtmp_$z";
      $ztype{$z}="P";
 } else {
      $pool{$z}="pool_default";
      $ztype{$z}="D";
    }
  }
  close ZCFG;
}


#
# Run several commands which summarize per-zone output for us.
# Actual pool cfg sizes may overwrite data collected above.

# Get amount of shared memory in use by each zone.
# "ipcs -mbZ" lists segments in all zones, but we must accumulate the sizes.
open(IPCS, "/usr/bin/ipcs -mbZ |");
while (<IPCS>) {
  if (/^m\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)/) {
    $shm_use{$2} += $1;
    $shm_use_sum += $1;
  }
}
close IPCS;

# Future: What is the default scheduler for each pool?
# poolcfg -dc info

# Get amount and cap of memory locked by processes in each zone.
# "kstat -p caps:*:lockedmem_zone_*" conveniently summarizes all zones for us.
#
open(KSTAT, "/usr/bin/kstat -p caps:*:lockedmem_zone_* |");
while (<KSTAT>) {
  if (/^caps:(\d+):lockedmem_zone_\d+:usage\s+(\d+)/) {
    $lkd_use[$1] = $2;
    $lkd_use_sum += $2;
  }
  if (/^caps:(\d+):lockedmem_zone_\d+:value\s+(\d+)/) {
    $lkd_cap[$1] = $2;
  }
}
close KSTAT;

# Get amount and cap of swap used by processes in each zone.
# "kstat -p caps:*:swapresv_zone_*" conveniently:
#  * summarizes all zones for us
#  * includes space used in all tmpfs mounts
#
open(KSTAT, "/usr/bin/kstat -p caps:*:swapresv_zone_* |");
while (<KSTAT>) {
  if (/^caps:(\d+):swapresv_zone_\d+:usage\s+(\d+)/) {
    $vm_use[$1] = $2;
    $vm_use_sum += $2;
$vm_use_sum += $2;
  }
  if (/^caps:(\d+):swapresv_zone_\d+:value\s+(\d+)/) {
    $vm_cap[$1] = $2;
  }
}
close KSTAT;

# For zones with RAM caps (U4+), get current values for RAM usage and Cap.
if ($update>3) {
  open (RCAP, "/usr/bin/svcs -H rcap|");
  $input=<RCAP>;
  close RCAP;
  if ($input =~ /online/) {
    $rcap_enabled=1;
    open (RCAP, "/usr/bin/rcapstat -z 1 1|");
    while (<RCAP>) {
      if (/^\s+\d+\s+(\S+)\s+\S+\s+\S+\s+(\S+)\s+(\S+)/) {
        $mem=&expand($2);
        $rss_use{$1} = $mem;
        $rss_use_sum += $mem;
        $rss_cap{$1} = $3;
      }
    }
    close RCAP;
  }
}


# Per-zone commands to gather more data. If there are many zones on the system,
# the amount of CPU time burned by this section can distort the results.

foreach $z (@names) {

# If rcap not enabled, or if this zone doesn't have a cap, we get current
# values for RAM usage with prstat. prstat consumes much more system time
# than other methods which might work (e.g. rcapstat).

  if (!defined($rss_use{$z})) {
    if ($z eq 'global') {
      open (PRSTAT, "/bin/prstat -cZz $z 1 1|");
    } else {
      open (PRSTAT, "/usr/sbin/zlogin $z /bin/prstat -cZ 1 1|");
    }
    while (<PRSTAT>) {
      if (/^ZONEID/) {
        $_=<PRSTAT>;
        /\s+\d+\s+\d+\s+(\S+)\s+(\S+)\s+\S+\s+\S+\s+([0-9\.]+)/;
        $mem = &expand($2);
        $rss_use{$z} = $mem;
        $rss_use_sum += $mem;
        $cpu_percent{$z} = $3;
  }
    }
    close PRSTAT;
  }


# Get current values for pool configurations. If pools not enabled, use the
# default pool.
# This should really be run once per outer loop, without -p, not once per zone.
  if ($pools_enabled =~ /online/) {
    open (POOLS, "/usr/bin/poolstat -r pset -p $pool{$z}|");
    while (<POOLS>) {
      if (/^\s+(\d+)\s$pool{$z}\s+pset\s+([0-9\-]+)\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)/) {
        $poolid{$z}  =$1;
        $poolmembers{$1} .= $z . ' ';
        $psetid{$z}  =$2;
        if ($psetid{$z} ==-1) { $psetid{$z}=0; }
        $pset_cfg_min{$z} =$3;
        $pset_cfg_max{$z} =$4;
        $pset_cur{$z} =$5;
        $poolsize{$1}=$5;
      }
    }
    close POOLS;
  } else {             # Pools not enabled
    $poolid{$z}=0;
    $poolmembers{0} .= $z . ' ';
    $pset_cur{$z} = $total_cpus;
    $pset_cfg_min{$z}=$pset_cur{$z};
    $pset_cfg_max{$z}=$pset_cur{$z};
  }
  if ($cpu_percent{$z}<0) { $cpu_percent{$z}=0; }

}

#
# For each zone, gather some caps.
if ($opt_l || $opt_P) {
  foreach $z (@names) {

    if ($update>4) {
      open(PRCTL, "/bin/prctl -Pi zone -n zone.cpu-cap $z|");
      while (<PRCTL>) {
        if (/.*privileged (\d+)/) {
          $cpu_cap{$z} = $1/100;
        }
      }
      close PRCTL;
    }

open(PRCTL, "/bin/prctl -Pi zone -n zone.cpu-shares $z|");
    while (<PRCTL>) {
      if (/.*privileged (\d+)/) {
        $cpu_shares{$z} = $1;
      }
    }
    close PRCTL;

    open(PRCTL, "/bin/prctl -Pi zone -n zone.max-shm-memory $z|");
    while (<PRCTL>) {
      if (/.*system (\d+)/) {  # Only use if no privileged entry.
        $system = $1;
      }
      if (/.*privileged (\d+)/) {
        $priv = $1;
      }
      $shm_cap{$z} = $priv ? $priv : $system;
#     if ($priv) { $shm_cap{$z} = $priv; }
#     else       { $shm_cap{$z} = $system; }
    }
    close PRCTL;
  }
}


#
# Summarize shares per pool to display the minimum portion of a pool
# which can be used by that zone.
for $z (@names) {
   $poolshares[$poolid{$z}] = 0;
}
for $z (@names) {
   $poolshares[$poolid{$z}] += $cpu_shares{$z};
}

# Get system info and tunable param's
#
open (MDB, "/bin/echo 'pages_pp_maximum/D;segspt_minfree/D' | mdb -k|");
while (<MDB>) {
  if (/pages_pp_maximum:\s+(\d+)/) {
     $lockable_mem=$RAM - $pagesize * $1;
  }
  if (/segspt_minfree:\s+(\d+)/) {
     $shareable_mem=$RAM - $pagesize * $1;
  }
}
close MDB;

# Note that swap(1M) doesn't report memory pages that the kernel has locked.
open (SWAP, "/usr/sbin/swap -s|");
  while (<SWAP>) {
 if (/= (\S+) used, (\S+)/) {
      $VM=&expand($1) + &expand($2);
    }
  }
close SWAP;

# Now that all data manipulation is complete, modify output data
# to match field sizes.
$VM            = &shorten ($VM);
$rss_use_sum   = &shorten ($rss_use_sum);
$shm_use_sum   = &shorten ($shm_use_sum);
$lkd_use_sum   = &shorten ($lkd_use_sum);
$vm_use_sum    = &shorten ($vm_use_sum);
$lockable_mem  = &shorten ($lockable_mem);
$shareable_mem = &shorten ($shareable_mem);

foreach $z (@names) {
# $pset_cfg_max{$z} = &shorten ($pset_cfg_max{$z});
  if ($cpu_shares{$z} > 999) { $cpu_shares{$z} = ">1K"; }
  $cpus_used_sum   += $cpu_percent{$z}*$pset_cur{$z}/100,
  $rss_use{$z}      = &shorten ($rss_use{$z});
  $shm_cap{$z}      = &shorten ($shm_cap{$z});
  $shm_use{$z}      = &shorten ($shm_use{$z});
  $lkd_cap[$zoneid{$z}] = &shorten ($lkd_cap[$zoneid{$z}]);
  $lkd_use[$zoneid{$z}] = &shorten ($lkd_use[$zoneid{$z}]);
  $vm_cap[$zoneid{$z}]  = &shorten ($vm_cap[$zoneid{$z}]);
  $vm_use[$zoneid{$z}]  = &shorten ($vm_use[$zoneid{$z}]);
  if ($opt_l || $opt_P) {
    $sh_in_pool{$z}       =  int(100*$cpu_shares{$z}/$poolshares[$poolid{$z}]);
  }
  if ($sh_in_pool{$z} == 100) { $sh_in_pool{$z} = 'HH'; }
}

#
# Display data
# 123456789112345678921234567893123456789412345678951234567896123456789712345678981
#         |----Pool-----|------CPU-------|----------------Memory----------------|
#         |---|--Size---|----------------|---RAM---|---Shm---|---Lkd---|---VM---|
# Zonename| IT| Max| Cur| Cap|Used|Shr|S%| Cap|Used| Cap|Used| Cap|Used| Cap|Used
#
# Data fields, ranges and sizes:
#   Zonename: 8 chars
#   PoolID: 2 chars. If >99, replace with HH
#   PoolType: 1 char.
#   Size:Max: 4 characters: 1-3 digits, optional suffix K, M, G, T, P, E
#   Size:Cur: 3 chars: "ddd"
#   CPU:Cap: 4 chars, one of "dddd", "d.dd", "dd.d"
#   CPU:Use: (same as CPU:Cap)
#   CPU:Shr: 3 chars. If >999, replace with ">1K"
#   CPU:Sh%: 2 chars. If =100, replace with 'H'
#   Memory:RAM:Cap: 4 chars: 1-3 digits, optional suffix K, M, G, T, P, E
#   Memory:RAM:Use: (same format as RAM:Cap)
#   Memory:Shm:Cap: (same format as RAM:Cap)
#   Memory:Shm:Use: (same format as RAM:Cap)
#   Memory:Lkd:Cap: (same format as RAM:Cap)
#   Memory:Lkd:Use: (same format as RAM:Cap)
#   Memory:VM:Cap: (same format as RAM:Cap)
#   Memory:VM:Use: (same format as RAM:Cap)

if ($doheader) {
  $doheader=0;
  if ($update<5) {
    if ($opt_l) {
printf ("        |----Pool-----|---CPU-----|----------------Memory----------------|\n");
printf ("        |---|--Size---|Pset-------|---RAM---|---Shm---|---Lkd---|---VM---|\n");
printf ("Zonename| IT| Max| Cur|Used|Shr|S%| Cap|Used| Cap|Used| Cap|Used| Cap|Used\n");
printf ("--------------------------------------------------------------------------\n");
    } elsif ($opt_P) {
printf ("Zonename:IT:Max:Cur:Used:Shr:S%:RAMCap:Used:ShmCap:Used:LkdCap:Used:VMCap:Used\n");
    } else {
printf ("        |--Pool--|Pset|-------Memory-----|\n");
printf ("Zonename| IT|Size|Used| RAM| Shm| Lkd| VM|\n");
printf ("------------------------------------------\n");
    }
  } else {
    if ($opt_l) {
printf ("        |----Pool-----|------CPU-------|----------------Memory----------------|\n");
printf ("        |---|--Size---|-----Pset-------|---RAM---|---Shm---|---Lkd---|---VM---|\n");
printf ("Zonename| IT| Max| Cur| Cap|Used|Shr|S%| Cap|Used| Cap|Used| Cap|Used| Cap|Used\n");
printf ("-------------------------------------------------------------------------------\n");
    } elsif ($opt_P) {
printf ("Zonename:IT:Max:Cur:Cap:Used:Shr:S%:RAMCap:Used:ShmCap:Used:LkdCap:Used:VMCap:Used\n");
    } else {
printf ("        |--Pool--|Pset|-------Memory-----|\n");
printf ("Zonename| IT|Size|Used| RAM| Shm| Lkd| VM|\n");
printf ("------------------------------------------\n");
    }
  }
} else {
  if (!$opt_P) { print ("--------\n"); }
}

# Group the zones by pool and print the pools in numerical order.
foreach $p (sort numerically keys (%poolmembers)) {
  $zones = $poolmembers{$p};
  foreach $z (split (/ /, $zones)) {
    if ($lines++ > 25 && !$opt_P) { $doheader=1; $lines=0; }
    if ($update<5) {
      if ($opt_l || $opt_P) {
        if ($opt_l) {
          $format = "%8s %2s%1s %4s %4s %4.1f %3s %2s %4s %4s %4s %4s %4s %4s %4s %4s\n";
        } else {
  $format = "%s:%s:%s:%s:%s:%.1f:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s\n";
        }
        printf ($format,
                $z, $poolid{$z}, $ztype{$z},
                $pset_cfg_max{$z}, $pset_cur{$z},
                $cpu_percent{$z}*$pset_cur{$z}/100,
                $cpu_shares{$z}, $sh_in_pool{$z},
                $rss_cap{$z}, $rss_use{$z}, $shm_cap{$z}, $shm_use{$z},
                $lkd_cap[$zoneid{$z}], $lkd_use[$zoneid{$z}],
                $vm_cap[$zoneid{$z}],  $vm_use[$zoneid{$z}]);
      } else {
        printf ("%8s %2s%1s %4s %4.1f %4s %4s %4s %4s\n",
                $z, $poolid{$z}, $ztype{$z},
                $pset_cur{$z},
                $cpu_percent{$z}*$pset_cur{$z}/100,
                $rss_use{$z}, $shm_use{$z},
                $lkd_use[$zoneid{$z}],
                $vm_use[$zoneid{$z}]);
       }
    } else  {
      if ($opt_l || $opt_P) {
        if ($opt_l) {
          $format = "%8s %2s%1s %4s %4s %4.1f %4.1f %3s %2s %4s %4s %4s %4s %4s %4s %4s %4s\n";
        } else {
          $format = "%s:%s:%s:%s:%s:%.1f:%.1f:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s\n",
        }
        printf ($format,
                $z, $poolid{$z}, $ztype{$z},
                $pset_cfg_max{$z}, $pset_cur{$z},
                $cpu_cap{$z}, $cpu_percent{$z}*$pset_cur{$z}/100,
                $cpu_shares{$z}, $sh_in_pool{$z},
                $rss_cap{$z}, $rss_use{$z}, $shm_cap{$z}, $shm_use{$z},
                $lkd_cap[$zoneid{$z}], $lkd_use[$zoneid{$z}],
                $vm_cap[$zoneid{$z}],  $vm_use[$zoneid{$z}]);
      } else {
        printf ("%8s %2s%1s %4s %4.1f %4s %4s %4s %4s\n",
                $z, $poolid{$z}, $ztype{$z},
                $pset_cur{$z},
                $cpu_percent{$z}*$pset_cur{$z}/100,
                $rss_use{$z}, $shm_use{$z},
                $lkd_use[$zoneid{$z}],
                $vm_use[$zoneid{$z}]);
      }
    }
  }
}
#
# Display totals and maxima
#
    $lines++;
    if ($update<5) {
if ($opt_l || $opt_P) {
        if ($opt_l) {
          $format = "==TOTAL= --- ---- %4s %4.1f --- -- %4s %4s %4s %4s %4s %4s %4s %4s\n";
        } else {
          $format = "==TOTAL=:::%s:%.1f:::%s:%s:%s:%s:%s:%s:%s:%s\n";
        }
        printf ($format, $total_cpus, $cpus_used_sum,
                &shorten($RAM), $rss_use_sum, $shareable_mem, $shm_use_sum,
                $lockable_mem, $lkd_use_sum,
                $VM, $vm_use_sum);
      } else {
        printf ("==TOTAL= --- %4s %4.1f %4s %4s %4s %4s\n",
                $total_cpus, $cpus_used_sum,
                $rss_use_sum, $shm_use_sum,
                $lkd_use_sum, $vm_use_sum);
      }
    } else  {
      if ($opt_l || $opt_P) {
        if ($opt_l) {
          $format = "==TOTAL= --- ---- %4s ---- %4.1f --- -- %4s %4s %4s %4s %4s %4s %4s %4s\n";
        } else {
          $format = "==TOTAL=:::%s::%.1f:::%s:%s:%s:%s:%s:%s:%s:%s\n";
        }
        printf ($format, $total_cpus, $cpus_used_sum,
                &shorten($RAM), $rss_use_sum, $shareable_mem, $shm_use_sum,
                $lockable_mem, $lkd_use_sum,
                $VM,  $vm_use_sum);
      } else {
        printf ("==TOTAL= === %4s %4.1f %4s %4s %4s %4s\n",
                $total_cpus, $cpus_used_sum,
                $rss_use_sum, $shm_use_sum,
                $lkd_use_sum, $vm_use_sum);
      }
    }

# All that processing takes at *least* one second...
sleep $interval>0 ? $interval-1 : 0;

undef @names;  # Handle zone transitions.
undef %poolmembers;
undef %rss_use;
$cpus_used_sum=0;
$rss_use_sum=0;
$shm_use_sum=0;
$lkd_use_sum=0;
$vm_use_sum=0;
$total_cpus=0;
}

