#!/usr/bin/perl

#

# psio - a "ps -ef" style tool that prints out disk %I/O. Solaris 9 (and older)

#

# This is designed to highlight processes that are causing the most disk I/O.

#  This version of psio runs prex on the kenel, and was more intended as a 

#  proof of concept than an everyday tool. The values may not be perfect.

#

# 10-Mar-2004, ver 0.68  (check for new versions, http://www.brendangregg.com)

#

#

# USAGE: psio [-efhmnxW] [-b buffer size] [seconds]

#	 psio [-efhmnxW] -i infile

#	 psio [-b buffer size] -o outfile [seconds]

#

#	psio		# default "ps -ef" style output, 1 second sample

#	psio 5		# sample for 5 seconds

#	psio -e		# event listing (raw and verbose)

#	psio -f		# full device output, print lines per device

#	psio -h		# print usage

#	psio --help	# print full help

#	psio -i infile	# read from infile (a psio dump)

#	psio -m		# mdb vnode lookups (for event mode). slow.

#	psio -n		# numbered output, Time(ms) Size(bytes) and Count

#	psio -o outfile	# write to outfile (create a psio dump)

#	psio -s		# reduced output, PID, %I/O and CMD only

#	psio -x		# extended output, %I/Ot %I/Os %I/Oc %CPU and %MEM

#	psio -W		# Don't print warnings

#	psio -b 10	# extra kernel buffer Kb size per second, default 100.

#

# Currently psio uses 300Kb + 100kb per sample second for the kernel buffer.

#  If you have a quiet system and would like to run long samples (> 5 mins),

#  "-b" can be used to reduce the buffer size to something appropriate.

#  Busy systems may need a larger value.

#

# To conduct careful analysis first write to an outfile, then run psio

#  with different options on the infile (eg, "-x", "-n", "-fn", "-e").

#

# In event mode using "-m" will run "mdb -k" to lookup pathmanes from

#  vnodes, which is slow but can be very helpful. If you are using event

#  mode on an old output file - then it's likely that the vnodes in memory 

#  will have changed and give unreliable results. See the INFO field 

#  below for the description of the special field from event mode.

#

#

# FIELDS:

#	%I/O	%I/O by time taken - duration of disk operation over 

#		available time (most useful field)

#	%I/Ot	same as above

#	%I/Os	%I/O by size - number of bytes transferred over total bytes

#		in sample

#	%I/Oc	%I/O by count - number of operations over total operations

#		in sample

#	IOTIME	Time taken for I/O (ms)

#	IOSIZE	Size of I/O (bytes)

#	IOCOUNT	Count of I/O (number of operations)

#	INFO	This contains the best info available: either a filename,

#		or a vnode number (0x...), or a block number, or nothing ".".

#

# WARNING: This tool runs prex on the kernel to activate kernel tracing, 

#  possibly the first time your server has ever enabled tracing!

#  This can be a dangerous activity - don't run this on production/critical

#  servers, best to run in development only.

#

#  Beware of running this for large sample periods ( > 120 seconds), as

#  the kernel buffer required to fetch the trace info can get huge -

#  keep an eye on memory. (optimising this is a todo item). 

#  You can tune this using the "-b" option. psio also saves a temporary file

#  in /tmp for procssing the I/O events, which itself could become large.

#

# SEE ALSO:	se -DWIDE pea.se	# SE Toolkit

#

# COPYRIGHT: Copyright (c) 2003, 2004 Brendan Gregg.

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

# Todo: 

#  * Tune kernel buffer size.

#  * More testing.

#  * More command line options.

#  * Record tagged queueing times correctly.

#  * Process raw I/O as well as block I/O.

#  * Add direction (In or Out) to event mode.

#

# 03-Dec-2003	Brendan Gregg	Created this

# 04-Dec-2003	   "      "	Trapped Ctrl-C, taint tested, reworked output.

# 06-Dec-2003	   "      "	More features (-e, -i, -o, -f, -n)





use Getopt::Std;



#

# --- Default Variables ---

#

$period = 1;				# seconds to sample

$buf_min = 300;				# min kernel buffer size (Kb)

$buf_psec = 100;			# extra kernel buffer per second

$tmpfile = "/tmp/.tnftmp.$$";		# tmp file for tnf data

$ENV{PATH} = "/usr/bin:/usr/sbin";	# secure $PATH

$DEBUG = 0;				# print debug info

$WARNING = 1;				# print warnings

$BYDEVICE = 0;				# print by device

$STYLE = 0;				# normal "ps -ef" style

$EVENT = 0;				# event mode (list all operations)

$OUTPUT = 0;				# file output mode

$INPUT = 0;				# file input mode

$MDB = 0;				# MDB vnode lookup for event mode

$Bit = `isainfo -b`;			# determine bit size

chomp($Bit);



#

# --- Command Line Arguments ---

#

&Help() if $ARGV[0] eq "--help";

getopts('efhmnsxDWb:i:o:') || &Usage();

&Usage() if $opt_h;

$WARNING = 0 if $opt_W;

$DEBUG = 1 if $opt_D;

$BYDEVICE = 1 if $opt_f;

$STYLE = 1 if $opt_x;		

$STYLE = 2 if $opt_s;		

$STYLE = 3 if $opt_n;

$EVENT = 1 if $opt_e;

$STYLE = -1 if $opt_e;

$OUTPUT = 1 if $opt_o;

$fileout = $opt_o if $OUTPUT;

$INPUT = 1 if $opt_i;

$MDB = 1 if $opt_m;

$filein = $opt_i if $INPUT;

$buf_psec = 0 + $opt_b if defined $opt_b;

$period = $ARGV[0] || $period;



### Calculate kernel buffer size

$buffer = $buf_min + $buf_psec * $period;



### Load device info if needed

&Load_DeviceInfo() if (($BYDEVICE || $EVENT || $OUTPUT) && (! $INPUT));





#

# --- Print header line ---

#

print "Please wait $period seconds, collecting data...\n" if $DEBUG;

unless ($OUTPUT) {

   if ($STYLE == 0) {

	print "     UID   PID  PPID %I/O    STIME TTY      TIME CMD\n";

   } elsif ($STYLE == 1) {

	print "     UID   PID %CPU %I/Ot %I/Os %I/Oc %MEM S   TIME CMD\n";

   } elsif ($STYLE == 2) {

	print "   PID %I/O CMD\n";

   } elsif ($STYLE == 3) {

	print "     UID   PID  IOTIME    IOSIZE IOCOUNT CMD\n";

   } elsif ($EVENT) {

	print "     UID   PID  IOTIME    IOSIZE DEVICE                   ".

	 " INFO CMD\n";

   }

}



### Cleanup on signals

$SIG{INT} = \&Cleanup_Trace;	# Ctrl-C

$SIG{QUIT} = \&Cleanup_Trace;	# Ctrl-\

$SIG{TERM} = \&Cleanup_Trace;	# TERM





if ($INPUT) {

	#

	# --- Read input from file ---

	#

	open(IN,$filein) || die "ERROR10: Can't read infile $filein: $!\n";



	$line = <IN>;

	($junk,$period) = split(' ',$line);



	$delim = 0;

	while ($line = <IN>) {

		if ($line =~ /^==========================/) {

			$delim++;

			next;

		}

		if ($delim == 0) {

			$ps_all .= $line;

		} elsif ($delim == 1) {

			push(@TNF,$line);

		} elsif ($delim == 2) {

			($key,$value) = split(/:/,$line);

			chomp($value);

			$DeviceFile{$key} = $value;

		} elsif ($delim == 3) {

			($key,$value) = split(/:/,$line);

			chomp($value);

			$MountPoint{$key} = $value;

		}

	}

} else {

	#

	# --- Sanity Check ---

	#

	if (! -r "/dev/mem") {

		die "ERROR1: Sorry, you must be root to run this.\n";

	}

	if ($buffer > 10 * 1024 ) {

		print STDERR "WARNING1: $period seconds is using a kernel " .

		 "buffer of ${buffer}Kb\n\n" if $WARNING;

	}



	#

	# --- Generate I/O tracing data ---

	#

	open(PREX,"| prex -k > /dev/null") || 

		die "ERROR2: Can't run prex (\$PATH/root?): $!\n";

	$oldfh = select(PREX); 

	$| = 1; 			# make this pipe "piping hot"

	select($oldfh); 

	print PREX "buffer alloc ${buffer}k\nenable io\ntrace io\nktrace on\n";

	sleep($period);

	print PREX "ktrace off\nquit\n";

	close PREX;



	#

	# --- Get ps data ---

	#

	$ps_all = 

	 `ps -eo pid,ruser,ppid,c,stime,tty,time,rss,vsz,pcpu,pmem,s,args` || 

		die "ERROR3: Can't run \"ps -eo pid,uid,...\": $!\n";

	

	#

	# --- Fetch I/O trace results ---

	#

	system("tnfxtract $tmpfile") && 

		die "ERROR4: Can't tnfxtract $tmpfile: $!\n";

	print "Created tnfxtrace $tmpfile (${buffer}Kb)\n" if $DEBUG;

	open(TNF,"tnfdump $tmpfile |") || 

		die "ERROR5: Can't read my $tmpfile: $!\n";

	@TNF = <TNF>;

	close TNF;



	#

	# --- Clear prex buffer ---

	#

	open(PREX,"| prex -k > /dev/null") || 

		die "ERROR6: Can't run prex (\$PATH/root?): $!\n";

	print PREX "buffer dealloc\nquit\n";

	close PREX;

}





#

# --- Save output file and exit if requested ---

#

if ($OUTPUT) {

	open(OUT,">$fileout") || die "ERROR9: Can't write to $fileout: $!\n";

	print OUT "period $period\n";

	print OUT $ps_all;

	print OUT "="x80,"\n";

	print OUT @TNF;

	print OUT "="x80,"\n";

	print OUT $devicefiles;

	print OUT "="x80,"\n";

	print OUT $mountpoints;

	close OUT;

	close TNF;

	exit (0);

}





#

# --- Process ps data ---

#

foreach $line (split("\n",$ps_all)) {

	next if $line =~ /^\s*PID/;

	($pid,$rest) = split(' ',$line,2);



	### Store in memory

	$Ps{$pid} = $rest;

}



#

# --- Process I/O trace results ---

#

$delim = 0;

foreach $line (@TNF) {

	### Skip header

	$delim++ if $line =~ /^-/;

	next if $delim < 2;



	### Get data

	($elapsed,$delta,$pid,$lwpid,$tid,$cpu,$probe,$rest) = 

	 split(' ',$line,8);



	#

	#  Store value - the time between I/O events

	#  These are usually the times between,

	# 	strategy -> biodone		# block device

	#

	if ($probe eq "pagein" || $probe eq "pageout") {

		($x,$vnode,$x,$offset,$x,$size,$rest) = split(' ',$rest);

		$Page{"$tid"} = $vnode;

	} elsif ($probe eq "strategy") {

		($x,$dev,$x,$blk,$x,$size,$rest) = split(' ',$rest);

		## $StrategyStart{"$dev:$blk"} = $elapsed;

		$Strategy{"$dev:$blk"}{pid} = $pid;

		$Strategy{"$dev:$blk"}{size} = $size;

		if ($Page{"$tid"}) {

			$Strategy{"$dev:$blk"}{vnode} = $Page{"$tid"};

			delete $Page{"$tid"};

		}

		$LastDev{"$dev"} = $elapsed;

	} elsif ($probe eq "biodone") {

		($x,$dev,$x,$blk,$x,$rest) = split(' ',$rest);

		if (defined $Strategy{"$dev:$blk"}{pid}) {



			## $start = $StrategyStart{"$dev:$blk"};

			## $truedelta = $elapsed - $start;

			#

			#  The above lines of code seem obvious, measuring

			#  the time between request and completion - but turns 

			#  out to be a poor estimation of disk I/O. What can 

			#  happen is we have several consecutive requests, that

			#  are then serviced by several consecutive 

			#  completions (tagged queueing - grouping the I/O 

			#  activity to improve performance). By counting the 

			#  deltas between all the requests within the group 

			#  can over-count the actual service time.

			#

			#  What is simple (and would be a "last resort") is

			#  to use the delta time in this event. This works

			#  most of the time - but can give poor results during

			#  simultaneous multiple disk access. Eg, a fast

			#  disk is accessed while a slow disk as accessed - 

			#  the delta on the slow disk completions can often

			#  be the delta to the last fast disk event - recording

			#  smaller than expected times.

			#

			#  Instead of the above we use the delta time between 

			#  this event and the last disk event on the device. 

			#  This gives almost perfect results (we still miss

			#  the small time taken to populate the tagged queue).

			#

			if (defined $LastDev{"$dev"}) {

				$truedelta = $elapsed - $LastDev{"$dev"};

				delete $LastDev{"$dev"};

			} else {

				$truedelta = $delta;    # (last resort)

			}



			### Fetch who really called this

			$pid = $Strategy{"$dev:$blk"}{pid};



			### Store I/O time

			$Delta{$pid} += $truedelta;

			$DeltaDev{$pid}{$dev} += $truedelta;

			$totalio_time += $truedelta;

			

			### Store I/O size

			$Size{$pid} += $size;

			$SizeDev{$pid}{$dev} += $size;

			$totalio_size += $size;



			### Store I/O count

			$Count{$pid}++;

			$CountDev{$pid}{$dev}++;

			$totalio_count++;



			### Store event details

			if ($EVENT) {

				$Event{$elapsed}{pid} = $pid;

				$Event{$elapsed}{size} = $size;

				$Event{$elapsed}{dev} = $dev;

				$Event{$elapsed}{block} = $blk;

				$Event{$elapsed}{delta} = $truedelta;

				$Event{$elapsed}{vnode} = 

				 $Strategy{"$dev:$blk"}{vnode} if defined 

				 $Strategy{"$dev:$blk"}{vnode};

			}



			delete $Strategy{"$dev:$blk"};

			print "Stored: PID($pid) Delta($truedelta)" .

			 " strategy -> biodone\n" if $DEBUG;

			

		}

		$LastDev{"$dev"} = $elapsed;

	} 

}

close TNF;

unlink($tmpfile) unless $DEBUG;



### Prevent divide by zero

$totalio_time = 1000 if $totalio_time == 0;

$totalio_size = 1 if $totalio_size == 0;

$totalio_count = 1 if $totalio_count == 0;





### Cap total I/O time at 100% - either heavy multiple disk access or

### 				 sampling errors (didn't sleep exactly)

$factor = 1;

$factor = (1000 * $period) / $totalio_time if $totalio_time > (1000 * $period);





# 

# --- Print event data if requested ---

#

if ($EVENT) {

	foreach $event (sort {$a <=> $b} (keys(%Event))) {



		### Fetch event details

		$pid = $Event{$event}{pid};

		$size = $Event{$event}{size};

		$dev = $Event{$event}{dev};

		$block = $Event{$event}{block};

		$delta = $Event{$event}{delta};

		$vnode = $Event{$event}{vnode};

		$info = $vnode;



		### Fetch device name

		$device = &Get_DeviceName($dev);

		$device =~ s/.*, //;	# full name is too long



		### Get process data

		$line = $Ps{$pid};

		if ($line eq "") {

		   ($ruser,$ppid,$c,$stime,$tty,$time,$rss,$vsz,$pcpu,$pmem,

		    $s,$args) = qw(? ? ? ? ? ? ? ? ? ? ? ?);

		} else {

		   ($ruser,$ppid,$c,$stime,$tty,$time,$rss,$vsz,$pcpu,$pmem,

		    $s,$args) = split(' ',$line,12);

		}



		### vnode lookup if MDB mode

		if ($MDB && ($vnode ne "")) {

		   if (defined $Mdb{$vnode}) {

			$info = $Mdb{$vnode};

		   } else {

			$mdb_out = `echo '${vnode}::vnode2path\n\$q' | mdb -k` 

			 || die "ERROR12: mdb error: $!, try without -m.\n";

			if ($mdb_out =~ /\S/) {

				($info) = $mdb_out =~ /^(\S*)/;

				$info =~ s/^\?\?//;

				$Mdb{$vnode} = $info;

			} 

		   }

		} 

		$info = $block if $info eq "";

		$info = "." if $info eq "";	# populate field if empty



		### Print formatted output

		printf("%8s %5s %7.0f %9s %-14s %15s %s\n",$ruser,$pid,$delta,

		 $size,$device,$info,$args);

	}

	exit (0);

}





#

# --- Print ps data with I/O ---

#

foreach $pid (sort {$Delta{$b} <=> $Delta{$a}} (keys(%Delta))) {

	$delta = $Delta{$pid};

	$size = $Size{$pid};

	$count = $Count{$pid};



	#

	#  Calculate percentages

	#

	$pcntio_time = $factor * $delta / (10 * $period); #/10 is ms -> %

	$pcntio_time = sprintf("%.1f",$pcntio_time);

	$pcntio_size = 100 * $size / $totalio_size;       # *100 makes it %

	$pcntio_size = sprintf("%.1f",$pcntio_size);

	$pcntio_count = 100 * $count / $totalio_count;    # *100 makes it %

	$pcntio_count = sprintf("%.1f",$pcntio_count);



	### Get process data

	$line = $Ps{$pid};



	#

	#  Some processes will begin and end too quickly - they

	#  will be seen by prex but not during the ps -ef sample.

	#  These have a mock ps -ef line generated to indicate this.

	#

	if ($line eq "") {

	   ($ruser,$ppid,$c,$stime,$tty,$time,$rss,$vsz,$pcpu,$pmem,$s,$args) =

	    qw(? ? ? ? ? ? ? ? ? ? ? ?);

	} else {

	   ($ruser,$ppid,$c,$stime,$tty,$time,$rss,$vsz,$pcpu,$pmem,$s,$args) =

	    split(' ',$line,12);

	   $stime =~ tr/_/ /;

	}



	#

	#  Format and print output

	#

	if ($STYLE == 0) {

		printf("%8s %5s %5s %4s %8s %-6s %6s %s\n",$ruser,$pid,$ppid,

		 $pcntio_time,$stime,$tty,$time,$args);

	} elsif ($STYLE == 1) {

		printf("%8s %5s %4s %5s %5s %5s %4s %1s %6s %s\n",$ruser,$pid,

		 $pcpu,$pcntio_time,$pcntio_size,$pcntio_count,$pmem,$s,

		 $time,$args);

	} elsif ($STYLE == 2) {

		printf("%6s %4s %s\n",$pid,$pcntio_time,$args);

	} elsif ($STYLE == 3) {

		printf("%8s %5s %7.0f %9s %7s %s\n",$ruser,$pid,$delta,

		 $size,$count,$args);

	}



	#

	#  Now print results on a device by device basis, if requested

	#

	if ($BYDEVICE) {

	   foreach $dev (sort {$DeltaDev{$pid}{$b} <=> 

	    $DeltaDev{$pid}{$a}} (keys(%{$DeltaDev{$pid}}))) {



		### Calculate percentages

		$delta = $DeltaDev{$pid}{$dev};

		$size = $SizeDev{$pid}{$dev};

		$count = $CountDev{$pid}{$dev};

		$pcntio_time = $factor * $delta / (10 * $period); 

		$pcntio_time = sprintf("%.1f",$pcntio_time);

		$pcntio_size = 100 * $size / $totalio_size;      

		$pcntio_size = sprintf("%.1f",$pcntio_size);

		$pcntio_count = 100 * $count / $totalio_count;  

		$pcntio_count = sprintf("%.1f",$pcntio_count);



		### Fetch device name

		$device = &Get_DeviceName($dev);



		### Format and print output

		if ($STYLE == 0) {

			printf("%8s %5s %5s %4s  %s\n",'"','"','"',

			 $pcntio_time,$device);

		} elsif ($STYLE == 1) {

			printf("%8s %5s %4s %5s %5s %5s   %s\n",'"','"',

		 	'"',$pcntio_time,$pcntio_size,$pcntio_count,$device);

		} elsif ($STYLE == 2) {

			printf("%6s %4s  %s\n",'"',$pcntio_time,$device);

		} elsif ($STYLE == 3) {

			printf("%8s %5s %7.0f %9s %7s  %s\n",'"','"',

			 $delta,$size,$count,$device);

		}

	   }

	}

			



	delete $Ps{$pid};

}



#

# --- Print leftover ps lines (%0) ---

#

foreach $pid (sort {$a <=> $b} (keys(%Ps))) {

	$line = $Ps{$pid};



	($ruser,$ppid,$c,$stime,$tty,$time,$rss,$vsz,$pcpu,$pmem,$s,$args) =

	 split(' ',$line,12);

	$stime =~ tr/_/ /;



	### Format and print output

	if ($STYLE == 0) {

		printf("%8s %5s %5s %4s %8s %-6s %6s %s\n",$ruser,$pid,$ppid,

		 "0.0",$stime,$tty,$time,$args);

	} elsif ($STYLE == 1) {

		printf("%8s %5s %4s %5s %5s %5s %4s %1s %6s %s\n",$ruser,$pid,

		 $pcpu,"0.0","0.0","0.0",$pmem,$s,$time,$args);

	} elsif ($STYLE == 2) {

		printf("%6s %4s %s\n",$pid,"0.0",$args);

	} elsif ($STYLE == 3) {

		printf("%8s %5s %7s %9s %7s %s\n",$ruser,$pid,0,0,0,$args);

	}



}







#########################

# --- SUBROUTINES ---

#



# Cleanup_Trace - stop kernel tracing and deallocate the buffer if a user

#		hits Ctrl-C.

#

sub Cleanup_Trace {

	my $err = 0;

	my $prex = "ktrace off\nbuffer dealloc\nquit\n";	# cleanup code



	print STDERR "ALERT1: Ctrl-C hit, stopping kernel trace\n";



	### Try cleanup through the existing pipe

	$SIG{PIPE} = 'IGNORE';

	print PREX $prex || do { $err = 1 };

	close PREX || do { $err = 1 };



	### Emergency cleanup - rerun prex

	if ($err) {

	   system("echo '$prex' | prex -k") && do {

		### Last resort - ask user for manual intervention

		print STDERR "ERROR7: Couldn't stop kernel trace!\n";

		print STDERR qq/\tRun "prex -k" then "ktrace off", "quit"\n/;

	   };

	} 



	exit (1);

}





# Load_DeviceInfo - Loads general device info for devicename lookups

#

sub Load_DeviceInfo {

	#

	#  Store device number to device filename lookup in %DeviceFile

	#

	foreach $file (</dev/dsk/*>) {

		@Stat = stat($file);

		if ($Bit == 64) {

			($major,$minor) = unpack('nn',pack('N',$Stat[6]));

			$major *= 2**30;        

			$filedev = $major + $minor;

		} else {

			$filedev = $Stat[6];

		}

		$DeviceFile{$filedev} = $file;

		$devicefiles .= "$filedev:$file\n";	# for output file

	}



	#

	#  Get mount point info in %MountPoint

	#

	open(MNTTAB,"/etc/mnttab") || 

		die "ERROR8: Can't read /etc/mnttab: $!\n";



	while ($line = <MNTTAB>) {

		($fs,$mount,$rest) = split(' ',$line,3);

		$MountPoint{$fs} = $mount;

		$mountpoints .= "$fs:$mount\n";		# for output file

	}

	close MNTTAB;

}





# Get_DeviceName - Gets the mount point or block device name from the

#		prex device number

#

sub Get_DeviceName {

	my $dev = shift;

	my ($line,$rest,$file,$filedev,$mount);

	

	### Quick fetch if already known

	if (defined $DeviceName{$dev}) { return $DeviceName{$dev}; }



	#

	#  Generate device name

	#

	$file = $DeviceFile{$dev};

	if (defined $file) {

		$DeviceName{$dev} = $file;

		if (defined $MountPoint{$file}) { 

			$DeviceName{$dev} .= ", $MountPoint{$file}";

		}

	} else {

		$DeviceName{$dev} = $dev;

	}



	### Return

	return $DeviceName{$dev};

}





# Usage - print a usage message and exit.

#

sub Usage {

	print STDERR <<END;

psio ver 0.68

USAGE: psio [-efhmnxW] [-b buffer size] [seconds]

       psio [-efhmnxW] -i infile

       psio [-b buffer size] -o outfile [seconds]

   eg,

      psio 2               # 2 second sample

      psio -x              # extended output, %I/Ot %I/Os %I/Oc %CPU and %MEM

      psio -e              # event listing (raw and verbose)

      psio --help          # print full help

END

	exit (1);

}





# Help - print help. Actually strip it from the comments

# 		at the top of the code.

#

sub Help {

	open (MYSELF,"$0") || die "ERROR8: I can't see myself: $!\n";

	@Myself = <MYSELF>;

	close MYSELF;



	### Print comment from top of code

	foreach $line (@Myself) {

		last if $line !~ /^#/;

		last if $line =~ /^# Todo:/;

		next if $line =~ m:^#!/usr/bin/perl:;

		$line =~ s/^# //;

		$line =~ s/^#//;

		print $line;

	}

	print "\n";



	exit(0);

}
