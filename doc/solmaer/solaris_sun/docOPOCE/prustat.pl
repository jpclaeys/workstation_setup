#!/usr/bin/perl

#

# prustat - Process utilisation stats: %CPU, %Mem, %Disk, %Net. Solaris 10.

#	Needs to run as root. This is a demonstration release - check for

#	newer optimised versions. Uses Kstat, DTrace and procfs.

#

# 12-Mar-2005, ver 0.50  (demonstration release, http://www.brendangregg.com)

#

#

# USAGE:

#       prustat [-cehinuwxz] [-p PID] [-s sort] [-t top] [interval] [count]

#

#      prustat               # %Utilisation

#      prustat -i            # + I/O stats

#      prustat -u            # + USR/SYS times

#      prustat -x            # + Context Switchs

#      prustat -c            # Clear screen

#      prustat -w            # Wide output

#      prustat -z            # Skip zero lines

#      prustat -e            # Extra precision

#      prustat -p PID        # this PID only

#      prustat -s sort       # sort on pid|cpu|mem|disk|net|utime|vctx|...

#      prustat -t lines      # print top number of lines only

#  eg,

#      prustat 2                # 2 second samples (first is historical)

#      prustat 10 5             # 5 x 10 second samples 

#      prustat -t 8 10 5        # 5 x 10 second samples, top 8 lines only

#      prustat -ct 20 5         # 20 lines with screen refresh each 5 seconds

#      prustat -iuxct 5 10      # multi output, all reports every 10 seconds

#      prustat -ct 22 -s cpu 5	# 22 lines, sort by cpu, every 5 secs

#      prustat -ct 22 -s mem 5	# 22 lines, sort by mem, every 5 secs

#      prustat -ct 22 -s net 5	# 22 lines, sort by network, every 5 secs

#      prustat -ct 22 -s disk 5	# 22 lines, sort by disk, every 5 secs

#

# FIELDS:

#		PID	Process ID

#		CPU	Percent CPU

#		Mem	Percent RAM

#		Disk	Percent Disk

#		Net	Percent Network

#		MAJF	Major Page Faults (disk I/O)

#		INBLK	In Blocks (disk I/O reads)

#		OUBLK	Out Blocks (disk I/O writes)

#		CHAR-kb	Character I/O Kbytes

#		COMM	Command name

#		USR	User Time

#		SYS 	System Time

#		WAIT	Wait for CPU Time

#		VCTX	Voluntary Context Switches (I/O bound)

#		ICTX	Involuntary Context Switches (CPU bound)

#		SYSC	System calls

#

# WARNING: This program will run DTrace to gather Disk and Network data.

#	This has not been fully tested on different environments to study the 

# 	impact of these extra measurements. For now this is a demonstration

#	release - best to run in development for short periods. Check for

#	newer versions and updates to this message.

#

# NOTE: There is no historical values for Disk or Network utilisation percent,

#	the first sample for these will always show zero. 

#

# REFERENCES: /usr/include/sys/procfs.h

#

# SEE ALSO: iosnoop, psio, prusage		# process Disk I/O

#           socketsnoop.d			# process TCP

#	    prstat -m				# USR/SYS times, ...

#

# COPYRIGHT: Copyright (c) 2005 Brendan Gregg.

#

#  This program is free software; you can redistribute it and/or

#  modify it under the terms of the GNU General Public License

#  as published by the Free Software Foundation; either version 2

#  of the License, or (at your option) any later version.

#

#  This program is distributed in the hope that it will be useful,

#  but WITHOUT ANY WARRANTY; without even the implied warranty of

#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the

#  GNU General Public License for more details.

#

#  You should have received a copy of the GNU General Public License

#  along with this program; if not, write to the Free Software Foundation,

#  Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

#

#  (http://www.gnu.org/copyleft/gpl.html)

#

# Author: Brendan Gregg  [Sydney, Australia]

#

# 12-Mar-2005	Brendan Gregg	Created this.



use Getopt::Std;

use Sun::Solaris::Kstat;

my $Kstat = Sun::Solaris::Kstat->new();





#

# --- Default Variables ---

#

$INTERVAL = 1;		# seconds to sample

$MAX = 1;		# max count of samples

$NEW = 0;		# skip summary output (new data only)

$WIDE = 0;		# print wide output (don't truncate)

$SCHED = 0;		# print PID 0

$TOP = 0;		# print top many only

$CLEAR = 0;		# clear screen before outputs

$ZERO = 0;		# if 1, skip zero entries (all 0.00)

$STYLE_UTIL = 1;	# default output style, utilisation

$STYLE_IO = 0;		# output style, I/O

$STYLE_CTX = 0;		# output style, Context Switches

$STYLE_TIME = 0;	# output style, Times

$STYLE_EXTRA = 0;	# output style, Extra precision

$MULTI = 0;		# multi report, multiple styles

$TARGET_PID = -1;	# target PID, -1 means all

$TIME_BEGIN = 1;	# start of interval, ns

$TIME_END = 1;		# end of interval, ns

$count = 1;		# current iteration

$NIC_DEF = 100_000_000; # default NIC speed (100 Mbps)



### Network card instance names

@Network = qw(dmfe bge be ce eri ge hme le ppp qfe rtls sppp iprb);

$Network{$_} = 1 foreach (@Network);





#

# --- Command Line Arguments ---

#

&Usage() if $ARGV[0] eq "--help";

getopts('cehinuwxzp:s:t:') || &Usage();

&Usage() if $opt_h;

$NEW = 1 if $opt_n;

$WIDE = 1 if $opt_w;

$CLEAR = 1 if $opt_c;

$ZERO = 1 if $opt_z;

$STYLE_IO = 1 if $opt_i;

$STYLE_CTX = 1 if $opt_x;

$STYLE_TIME = 1 if $opt_u;

$STYLE_EXTRA = 1 if $opt_e;

$STYLE_IO = 1 if $opt_i;

$STYLE_UTIL = 0 if $opt_i || $opt_x || $opt_u || $opt_e;

$TOP = $opt_t if defined $opt_t;

$SORT = $opt_s if defined $opt_s;

$TARGET_PID = $opt_p if defined $opt_p;

$MAX = 2**32 if @ARGV == 1;

$INTERVAL = shift(@ARGV) || $INTERVAL;

$MAX = shift(@ARGV) || $MAX;

$CLEARSTR = `clear` if $CLEAR;

$MULTI = 1 if ($STYLE_IO + $STYLE_CTX + $STYLE_TIME) > 1;





#

# --- Determine Network Capacity ---

#

my ($error,$time,$module,$instance,$name);

my ($bytes,$rbytes,$wbytes);

my (%Modules,%Instances,%Names);

$NIC_SPEED = 0;		# sum of Mbps across all NICs



### Loop over all NICs

foreach $module (keys(%$Kstat)) {

	next unless $Network{$module};

	$Modules = $Kstat->{$module};

	foreach $instance (keys(%$Modules)) {

		$Instances = $Modules->{$instance};

		foreach $name (keys(%$Instances)) {

			$Names = $Instances->{$name};

			if (defined $$Names{ifspeed}) {

				$NIC_SPEED += $$Names{ifspeed};

			} else {

				$NIC_SPEED += $NIC_SPEED;

			}

		}

	}

}

$NIC_SPEED = $NIC_DEF if $NIC_SPEED == 0;





#

# --- Open DTrace ---

#

@Dscript = <DATA>;

$dscript = join('',@Dscript);

open(DTRACE,"$dscript 2>/dev/null |") || die("ERROR1: Can't open dtrace: $!\n");



### Cleanup on signals

$SIG{INT} = \&Cleanup;

$SIG{QUIT} = \&Cleanup;

$SIG{TERM} = \&Cleanup;

$SIG{PIPE} = \&Cleanup;





#

# --- Main ---

#

for (;$count <= $MAX; $count++) {

 

	### Get CPU and Mem data

	&GetProcStat();	

 

	next if $NEW && $count == 1;

 

	### Preprocess PID

	&ProcessPID();

 

	### Print data

	print $CLEARSTR if $CLEAR;

	&PrintUtil($SORT) if $STYLE_UTIL;

	&PrintExtra($SORT) if $STYLE_EXTRA;

	&PrintIO($SORT) if $STYLE_IO;

	&PrintCtx($SORT) if $STYLE_CTX;

	&PrintTime($SORT) if $STYLE_TIME;

 

	### Cleanup memory

	undef %Comm;

	undef %PID;

	$TIME_BEGIN = $TIME_END;

 

	### Get Disk and Net data

	for ($pause = 0; $pause < $INTERVAL; $pause++) {

		&GetDTraceStat();

	}

}



close(DTRACE);





#

# --- Subroutines ---

#



# GetProcStat - Gets /proc usage statistics and saves them in %PID.

#	This can be run multiple times, the first time %PID will be 

#	populated with the summary since boot values.

#	This reads /proc/*/usage and /proc/*/prstat.

#

sub GetProcStat {

   my $pid;

   chdir "/proc";

 

   ### Main PID Loop

   foreach $pid (sort {$a<=>$b} <*>) {

	next if $pid == $$;

	next if $pid == 0 && $SCHED == 0;

	next if $TARGET_PID > -1 && $pid != $TARGET_PID;

 

	### Read usage stats

	open(USAGE,"/proc/$pid/usage") || next;	

	read(USAGE,$usage,256);

	close USAGE;

	

	### Unpack usage values

	($pr_lwpid, $pr_count, $pr_tstamp, $pr_create, $pr_term, 

	 $pr_rtime, $pr_utime, $pr_stime, $pr_ttime, $pr_tftime, 

	 $pr_dftime, $pr_kftime, $pr_ltime, $pr_slptime, $pr_wtime, 

	 $pr_stoptime, $filltime, $pr_minf, $pr_majf, $pr_nswap, 

	 $pr_inblk, $pr_oublk, $pr_msnd, $pr_mrcv, $pr_sigs, 

	 $pr_vctx, $pr_ictx, $pr_sysc, $pr_ioch, $filler) = 

	 unpack("iia8a8a8a8a8a8a8a8a8a8a8a8a8a8a48LLLLLLLLLLLLa40",$usage);

 

	### Process usage values

	$New{$pid}{utime} = timestruct2int($pr_utime);

	$New{$pid}{stime} = timestruct2int($pr_stime);

	$New{$pid}{ttime} = timestruct2int($pr_ttime);

	$New{$pid}{ltime} = timestruct2int($pr_ltime);

	$New{$pid}{wtime} = timestruct2int($pr_wtime);

	$New{$pid}{slptime} = timestruct2int($pr_slptime);

	$New{$pid}{minf}  = $pr_minf;

	$New{$pid}{majf}  = $pr_majf;

	$New{$pid}{nswap} = $pr_nswap;

	$New{$pid}{inblk} = $pr_inblk;

	$New{$pid}{oublk} = $pr_oublk;

	$New{$pid}{vctx}  = $pr_vctx;

	$New{$pid}{ictx}  = $pr_ictx;

	$New{$pid}{sysc}  = $pr_sysc;

	$New{$pid}{ioch}  = $pr_ioch;

	# and a couple of my own,

	$New{$pid}{blks}  = $pr_inblk + $pr_oublk;

	$New{$pid}{ctxs}  = $pr_vctx + $pr_ictx;

 



	### Read psinfo stats

	open(PSINFO,"/proc/$pid/psinfo") || next;	

	read(PSINFO,$psinfo,256);

	close PSINFO;

	

	### Unpack psinfo values

	($pr_flag, $pr_nlwp, $pr_pid, $pr_ppid, $pr_pgid, $pr_sid,

	 $pr_uid, $pr_euid, $pr_gid, $pr_egid, $pr_addr, $pr_size,

	 $pr_rssize, $pr_pad1, $pr_ttydev, $pr_pctcpu, $pr_pctmem, 

	 $pr_start, $pr_time, $pr_ctime, $pr_fname, $pr_psargs, 

	 $pr_wstat, $pr_argc, $pr_argv, $pr_envp, $pr_dmodel, 

	 $pr_taskid, $pr_projid, $pr_nzomb, $pr_poolid, $pr_zoneid, $filler) = 

	 unpack("iiiiiiiiiiIiiiiSSa8a8a8Z16Z80iiIIaa3iiiiii",$psinfo);

 

	### Process psinfo values

	$PID{$pid}{pctcpu} = $pr_pctcpu / 0x8000;

	$PID{$pid}{pctmem} = $pr_pctmem / 0x8000;

	$PID{$pid}{uid} = $pr_uid;

	$New{$pid}{size}   = $pr_size;

	$New{$pid}{rssize} = $pr_rssize;

	

	### Save command name

	$Comm{$pid} = $pr_fname;

   }

  

   ### Turn incrementals into values

   foreach $pid (keys %New) {

	# save PID values,

	foreach $key (keys %{$New{$pid}}) {

		$PID{$pid}{$key} = $New{$pid}{$key} - $Old{$pid}{$key};

	}

   }

   undef %Old;

 

   ### Remember old value

   foreach $pid (keys %New) {

	# save old values,

	foreach $key (keys %{$New{$pid}}) {

		$Old{$pid}{$key} = $New{$pid}{$key};

	}

   }

}





# GetDTraceStat - read detals from a DTrace connection until a heartbeat

#	is read (happens every second).

#

sub GetDTraceStat {

	my ($line,$cmd,$rest,$uid,$pid,$size,$name,$delta);

 

	while ($line = <DTRACE>) {

		chomp($line);

		($cmd,$rest) = split(' ',$line,2);

	

		### Start

		$TIME_BEGIN = $rest if $cmd eq "B";

  

		### Heartbeat

		if ($cmd eq "T") {

			$TIME_END = $rest;

			last;

		}

  

		### Network traffic

		if ($cmd eq "N") {

			($uid,$pid,$size,$name) = split(' ',$rest);

			next if $TARGET_PID > -1 && $pid != $TARGET_PID;

			$PID{$pid}{netrw} += $size;

			unless (defined $Comm{$pid}) {

				$Comm{$pid} = $name;

				$PID{$pid}{uid} = $uid;

			}

		}

 

		### Disk traffic

		if ($cmd eq "D") {

			($uid,$pid,$delta,$size,$name) = split(' ',$rest);

			next if $TARGET_PID > -1 && $pid != $TARGET_PID;

			$PID{$pid}{dtime} += $delta;

			unless (defined $Comm{$pid}) {

				$Comm{$pid} = $name;

				$PID{$pid}{uid} = $uid;

			}

		}

	}

}



# ProcessPID - pre process %PID before printing.

#	This calculates values such as sumpct for sorting.

#

sub ProcessPID {

	my ($pid,$cpu,$mem,$disk,$net,$sample);

	my ($factorcpu,$factormem,$factordisk,$factornet);

 

	### Factors for %util conversions

	$sample = $TIME_END - $TIME_BEGIN || 1;

	$factorcpu = 100;

	$factormem = 100;

	$factordisk = 100 / $sample;

	$factornet = 800 / ($NIC_SPEED * ($sample / 1_000_000_000));

 

	### Process %PID

	foreach $pid (keys(%PID)) {

		$cpu = $PID{$pid}{pctcpu} * $factorcpu;

		$mem = $PID{$pid}{pctmem} * $factormem;

		$disk = $PID{$pid}{dtime} * $factordisk;

		$net = $PID{$pid}{netrw} * $factornet;

		$PID{$pid}{cpu} = $cpu;

		$PID{$pid}{mem} = $mem;

		$PID{$pid}{disk} = $disk;

		$PID{$pid}{net} = $net;

		$PID{$pid}{all} = $cpu + $mem + $disk + $net;

	}

}



# PrintUtil - print a report on utilisation.

#

sub PrintUtil {

	my $sort = shift || "all";

	my $top = $TOP;

	my ($pid,$cpu,$mem,$disk,$net,$all);

    

	### Print header

	printf("%5s %6s %6s %6s %6s  %s\n","PID",

	 "%CPU","%Mem","%Disk","%Net","COMM");

 

	### Print report

	foreach $pid (&SortPID("$sort")) {

 

		# Fetch utilisations

		$cpu = $PID{$pid}{cpu};

		$mem = $PID{$pid}{mem};

		$disk = $PID{$pid}{disk};

		$net = $PID{$pid}{net};

		$all = $PID{$pid}{all};

		

		# Skip zero lines if needed

		if ($ZERO && ($all < 0.02)) { next; }

 

		# Print output

		printf("%5s %6.2f %6.2f %6.2f %6.2f  %s\n",$pid,

		 $cpu,$mem,$disk,$net,trunc($Comm{$pid},33));

		last if --$top == 0;

	}

	print "\n" if $MULTI;

}



# PrintExtra - print a report on utilisation, with extra decimal places.

#

sub PrintExtra {

	my $sort = shift || "all";

	my $top = $TOP;

	my ($pid,$cpu,$mem,$disk,$net,$all);

    

	### Print header

	printf("%5s %8s %8s %8s %8s  %s\n","PID",

	 "%CPU","%Mem","%Disk","%Net","COMM");

 

	### Print report

	foreach $pid (&SortPID("$sort")) {

 

		# Fetch utilisations

		$cpu = $PID{$pid}{cpu};

		$mem = $PID{$pid}{mem};

		$disk = $PID{$pid}{disk};

		$net = $PID{$pid}{net};

		$all = $PID{$pid}{all};

		

		# Skip zero lines if needed

		if ($ZERO && ($all < 0.02)) { next; }

 

		# Print output

		printf("%5s %8.4f %8.4f %8.4f %8.4f  %s\n",$pid,

		 $cpu,$mem,$disk,$net,trunc($Comm{$pid},33));

		last if --$top == 0;

	}

	print "\n" if $MULTI;

}



# PrintIO - print a report with I/O statistics: minf, majf, inblk, oublk, ioch.

#

sub PrintIO {

	my $sort = shift || "blks";

	my $top = $TOP;

	my ($pid,$cpu,$mem,$disk,$net,$all);

    

	### Print header

	printf("%5s %6s %6s %6s %6s %8s %8s %9s %s\n","PID",

	 "%CPU","%Mem","%Disk","%Net","INBLK","OUBLK",

	 "CHAR-kb","COMM");

 

	### Print report

	foreach $pid (&SortPID("$sort")) {

 

		# Fetch utilisations

		$cpu = $PID{$pid}{cpu};

		$mem = $PID{$pid}{mem};

		$disk = $PID{$pid}{disk};

		$net = $PID{$pid}{net};

		$all = $PID{$pid}{all};

		

		# Skip zero lines if needed

		if ($ZERO && ($all < 0.02)) { next; }

 

		# Print output

		printf("%5s %6.2f %6.2f %6.2f %6.2f %8d %8d %9.0f %s\n",

		 $pid,$cpu,$mem,$disk,$net,$PID{$pid}{inblk},

		 $PID{$pid}{oublk},$PID{$pid}{ioch}/1024,

		 trunc($Comm{$pid},33));

		last if --$top == 0;

	}

	print "\n" if $MULTI;

}



# PrintTime - print a report including usr, sys and wait times.

#

sub PrintTime {

	my $sort = shift || "cpu";

	my $top = $TOP;

	my ($pid,$cpu,$mem,$disk,$net,$all);

    

	### Print header

	printf("%5s %6s %6s %6s %6s %8s %8s %8s %s\n","PID",

	 "%CPU","%Mem","%Disk","%Net","USR","SYS",

	 "WAIT","COMM");

 

	### Print report

	foreach $pid (&SortPID("$sort")) {

 

		# Fetch utilisations

		$cpu = $PID{$pid}{cpu};

		$mem = $PID{$pid}{mem};

		$disk = $PID{$pid}{disk};

		$net = $PID{$pid}{net};

		$all = $PID{$pid}{all};

		

		# Skip zero lines if needed

		if ($ZERO && ($all < 0.02)) { next; }

 

		# Print output

		printf("%5s %6.2f %6.2f %6.2f %6.2f %8d %8d %8d %s\n",

		 $pid,$cpu,$mem,$disk,$net,$PID{$pid}{utime},

		 $PID{$pid}{stime},$PID{$pid}{wtime},

		 trunc($Comm{$pid},33));

		last if --$top == 0;

	}

	print "\n" if $MULTI;

}



# PrintCtx - print a report on context switches: vctx, ictx and sys calls.

#

sub PrintCtx {

	my $sort = shift || "ctxs";

	my $top = $TOP;

	my ($pid,$cpu,$mem,$disk,$net,$all);

    

	### Print header

	printf("%5s %6s %6s %6s %6s %8s %8s %9s %s\n","PID",

	 "%CPU","%Mem","%Disk","%Net","VCTX","ICTX",

	 "SYSC","COMM");

 

	### Print report

	foreach $pid (&SortPID("$sort")) {

 

		# Fetch utilisations

		$cpu = $PID{$pid}{cpu};

		$mem = $PID{$pid}{mem};

		$disk = $PID{$pid}{disk};

		$net = $PID{$pid}{net};

		$all = $PID{$pid}{all};

		

		# Skip zero lines if needed

		if ($ZERO && ($all < 0.02)) { next; }

 

		# Print output

		printf("%5s %6.2f %6.2f %6.2f %6.2f %8d %8d %9d %s\n",

		 $pid,$cpu,$mem,$disk,$net,$PID{$pid}{vctx},

		 $PID{$pid}{ictx},$PID{$pid}{sysc},

		 trunc($Comm{$pid},33));

		last if --$top == 0;

	}

	print "\n" if $MULTI;

}



# SortPID - sorts the PID hash by the key given as arg1, returning a sorted

#	array of PIDs.

#

sub SortPID {

	my $sort = shift;

	

	### Sort numerically

	if ($sort eq "pid") {

   		return sort {$a <=> $b} (keys %PID);

	} else {

   		return sort {$PID{$b}{$sort} <=> $PID{$a}{$sort}} (keys %PID);

	}

}



# timestruct2int - Convert a timestruct value (64 bits) into an integer

#	of seconds.

#

sub timestruct2int {

	my $timestruct = shift;

	my ($secs,$nsecs) = unpack("LL",$timestruct);

	my $time = $secs + $nsecs * 10**-9;

	return $time;

}



# trunc - Returns a truncated string if required.

#

sub trunc {

	my $string = shift;

	my $length = shift;



	if ($WIDE) {

		return $string;

	} else {

		return substr($string,0,$length);

	}

}



# Cleanup - subroutine for signal management.

#

sub Cleanup {

	close(DTRACE);

	exit(0);

}



# Usage - print usage message and exit.

#

sub Usage {

	print STDERR <<END;

prustat ver 0.50, demo release

USAGE: prustat [-cehinuwxz] [-p PID] [-s sort] [-t top] [interval] [count]



      prustat               # \%Utilisation

      prustat -i            # + I/O stats

      prustat -u            # + USR/SYS times

      prustat -x            # + Context Switchs

      prustat -c            # Clear screen

      prustat -w            # Wide output

      prustat -z            # Skip zero lines

      prustat -e            # Extra precision

      prustat -p PID        # this PID only

      prustat -s sort       # sort on pid|cpu|mem|disk|net|utime|vctx|...

      prustat -t lines      # print top number of lines only

  eg,

      prustat 2                # 2 second samples (first is historical)

      prustat 10 5             # 5 x 10 second samples 

      prustat -t 8 10 5        # 5 x 10 second samples, top 8 lines only

      prustat -ct 20 5         # 20 lines with screen refresh each 5 seconds

      prustat -iuxct 5 10      # multi output, all reports every 10 seconds

      prustat -ct 22 -s cpu 5	# 22 lines, sort by cpu, every 5 secs

      prustat -ct 22 -s mem 5	# 22 lines, sort by mem, every 5 secs

      prustat -ct 22 -s net 5	# 22 lines, sort by network, every 5 secs

      prustat -ct 22 -s disk 5	# 22 lines, sort by disk, every 5 secs

 

END

	exit;

}



#

# --- DTrace ---

#



__DATA__

/usr/sbin/dtrace -n '

/*

** The following is a trimmed version of two seperate DTrace scripts:

**

** socketsnoop.d - snoop TCP network socket traffic by process. 

**  This is intended to identify the process responsible

**  for network traffic. Written in DTrace (Solaris 10 build 63).

**

** iosnoop.d - A program to print I/O events as they happen, with useful

**	details such as UID, PID, inode, command, etc. 

**	Written in DTrace (Solaris 10 build 63).

**

*/



#pragma D option quiet





/*

** --- TIMESTAMPS ---

*/

dtrace:::BEGIN {

	printf("B %d\n",timestamp);

	/* last is used as a timestamp to the disk request, OR,

	   to the last disk completion. This is needed to avoid 

	   over counting disk times due to disk buffers (queues),

	   however remains a minor simplification. */

	last = timestamp;

}

profile:::tick-1sec {

	/* heartbeat */

	printf("T %d\n",timestamp);

}





/*

** --- DISK ----

*/



/*

**  Store entry details

*/

io:::start

{

	this->dev = args[0]->b_edev;

	this->blk = args[0]->b_blkno;

	start_uid[this->dev,this->blk] = curpsinfo->pr_euid;

	start_pid[this->dev,this->blk] = pid;

	start_comm[this->dev,this->blk] = (char *)curpsinfo->pr_fname;

	last = timestamp;

}



/*

**  Process completion

*/

io:::done

{

	/* fetch entry values */

	this->dev = args[0]->b_edev;

	this->blk = args[0]->b_blkno;

	this->delta = timestamp - last;

	this->suid = start_uid[this->dev,this->blk];

	this->spid = start_pid[this->dev,this->blk];

	this->scomm = start_comm[this->dev,this->blk];



	/* memory cleanup */

	start_uid[this->dev,this->blk] = 0;

	start_pid[this->dev,this->blk] = 0;

	start_comm[this->dev,this->blk] = 0;

	last = timestamp;

}



/*

**  Print event details

*/

io:::done 

{

        printf("D %d %d %d %d %s\n",

         this->suid,this->spid,this->delta,args[0]->b_bcount,

         this->scomm == 0 ? "." : stringof(this->scomm));

}





/*

** --- NETWORK ----

*/



/*

**  Store Write Values

*/

fbt:ip:tcp_output:entry

{

        self->uid = curpsinfo->pr_euid;

        self->pid = pid;

        self->comm = (char *)curpsinfo->pr_fname;

        self->size = msgdsize(args[1]);

	self->ok = 1;

}



/*

**  Store Read Values

*/

fbt:sockfs:sotpi_recvmsg:entry

{

        self->uid = curpsinfo->pr_euid;

        self->pid = pid;

        self->comm = (char *)curpsinfo->pr_fname;

	/* We track the read request (man uio), */

	self->uiop = (struct uio *) arg2;

	self->residual = self->uiop->uio_resid;

	/* The following ensures the type is AF_INET (sys/socket.h), */

	this->sonode = (struct sonode *)arg0;

	self->ok = (int)this->sonode->so_type == 2 ? 1 : 0;

}

fbt:sockfs:sotpi_recvmsg:return

/arg0 != 0 && self->ok/

{

	/* calculate successful read size */

	self->size = self->residual - self->uiop->uio_resid;

}



/*

**  Print output

*/

fbt:ip:tcp_output:entry, fbt:sockfs:sotpi_recvmsg:return 

/self->ok/ 

{

        printf("N %d %d %d %s\n",self->uid,self->pid,

	 self->size,stringof(self->comm));

	self->ok = 0;

	self->uid = 0;

	self->pid = 0;

	self->comm = 0;

	self->size = 0;

	self->residual = 0;

	self->uiop = 0;

}

'
