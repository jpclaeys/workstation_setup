#!/usr/bin/perl
#
# DESCRIPTION: Call testcases included in check-multipath.pl (in current directory)
#              and compare output with expected result.
#
#              Put this script in the same directory as check-multipath.pl 
#              and call ./TEST_check-multipath.pl
#
#              ALWAYS USE IDENTICAL VERSIONS OF THE TWO SCRIPTS!
#
#
# AUTHOR:      Hinnerk Rümenapf (hinnerk.ruemenapf@rrz.uni-hamburg.de)
#
# Copyright (C) 2013-2016 
# Hinnerk Rümenapf
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#  Vs  0.1.7    Created test script for corresponding version of check-multipath.pl, Initial Version
#      0.1.7a   Improvements, return-code handling
#      0.1.8    Testcases for LUN names without HEX-ID
#      0.1.9    So far NO testcases for new Option --extraconfig, just minor changes.
#      0.2.0    new testcases
#      0.2.1    new testcase
#      0.3.0    new testcase
#      0.4.0    new testcases; new definition of testcases, define command for each testcase
#      0.4.5    new testcases, partly changed output of plugin  8/2016
#      0.4.6    Bugfix, new testcase
#      0.4.7    Compatibility with CentOS/RHEL 5-7
#

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);


# === Version and similar info ===
my $NAME    = 'TEST_check-multipath.pl';
my $VERSION = '0.4.7   03. AUG 2016';
my $AUTHOR  = 'Hinnerk Rümenapf';
my $CONTACT = 'hinnerk [DOT] ruemenapf [AT] uni-hamburg [DOT] de   hinnerk [DOT] ruemenapf [AT] gmx [DOT] de';


# Exit codes
my $E_OK       = 0;
my $E_WARNING  = 1;
my $E_CRITICAL = 2;
my $E_UNKNOWN  = 3;

# Nagios error levels reversed
my %reverse_exitcode
  = (
     0 => 'OK',
     1 => 'WARNING',
     2 => 'CRITICAL',
     3 => 'UNKNOWN',
    );



#
# Test definitions
#  - command to use
#  - expected return code
#  - exptected test output
#
my @testDefinitions = (

{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 1",  'ret' => $E_OK,         # 1
  'out' => "O: LUN mpathb: 4/4.;O: LUN mpatha: 4/4.;" 
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 2", 'ret' => $E_WARNING,     # 2
  'out' => "W: LUN mpathb: less than 4 paths (3/4).;O: LUN mpatha: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 3",  'ret' => $E_CRITICAL,   # 3
  'out' => "C: LUN mpathb: less than 2 paths (0/4)!;C: LUN mpatha: less than 2 paths (0/4)!;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 4",  'ret' => $E_OK,         # 4
  'out' => "O: LUN mpathb: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 5",  'ret' => $E_WARNING,    # 5
  'out' => "W: LUN mpathb: less than 4 paths (2/4).;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 6",  'ret' => $E_CRITICAL,   
  'out' => "C: LUN mpathb: less than 2 paths (1/4)!;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 7",  'ret' => $E_CRITICAL,
  'out' => "C: LUN mpathb: less than 2 paths (0/4)!;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 8",  'ret' => $E_CRITICAL,
  'out' => "C: LUN mpathb: less than 2 paths (1/4)!;C: LUN mpatha: less than 2 paths (1/4)!;W: LUN mpatha, path sde: ERROR.;W: LUN mpatha, path sdc: ERROR.;W: LUN mpathb, path sdk: NOT active.;W: LUN mpathb, path sdh: ERROR.;W: LUN mpathb, path sdf: ERROR.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 9",  'ret' => $E_WARNING,
  'out' => "W: No LUN found or no multipath driver.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 10", 'ret' => $E_UNKNOWN,
  'out' => "ERROR: Line 4 not recognised. Expected path info, new LUN or nested policy:\n'4:0:1:1 sdd 8:48  active ready running' |TESTCASE|\n"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 11", 'ret' => $E_UNKNOWN,
  'out' => "ERROR: Line 1 not recognised. Expected path info, new LUN or nested policy:\n'mpatha 36000d77b000048d117c68c81bf7c160a) dm-0 FALCON,IPSTOR DISK' |TESTCASE|\n"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 12", 'ret' => $E_UNKNOWN,
  'out' => "ERROR: Line 2 not recognised. Expected LUN info:\n'sisze=2.0T features='1 queue_if_no_path' hwhandler='0' wp=rw' |TESTCASE|\n"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 13", 'ret' => $E_UNKNOWN,
  'out' => "ERROR: Path info before LUN name. Line 1:\n'  |- 4:0:1:1 sdd 8:48  active ready running' |TESTCASE|\n"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 14", 'ret' => $E_OK,
  'out' => "O: LUN mpathb: 4/4.;O: LUN mpatha: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 15", 'ret' => $E_CRITICAL,
  'out' => "C: LUN mpatha: less than 2 paths (1/4)!;W: LUN mpathb: less than 4 paths (2/4).;W: LUN mpatha, path sdh: ERROR.;W: LUN mpatha, path sdd: ERROR.;W: LUN mpatha, path sdc: NOT active.;W: LUN mpathb, path sde: ERROR.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 16", 'ret' => $E_CRITICAL,
  'out' => "C: LUN dm-0: less than 2 paths (1/4)!;O: LUN dm-2: 4/4.;O: LUN dm-5: 4/4.;"},

{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 17", 'ret' => $E_CRITICAL,
  'out' => "C: LUN dm-0: less than 2 paths (1/4)!;W: LUN dm-2: less than 4 paths (3/4).;W: LUN dm-5, path sdj: ERROR.;W: LUN dm-2, path sdc: NOT active.;W: LUN dm-5: less than 4 paths (2/4).;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 18", 'ret' => $E_OK,
  'out' => "O: LUN MYVOLUME: 8/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 19", 'ret' => $E_WARNING,
  'out' => "W: LUN MYVOLUME, path sdj: NOT active.;W: LUN MYVOLUME, path sdh: ERROR.;W: LUN MYVOLUME, path sde: ERROR.;O: LUN MYVOLUME: 5/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 20", 'ret' => $E_OK,
  'out' => "O: LUN foobar_postgresql_lun0: 4/4.;O: LUN foobar_backup_lun0: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 21", 'ret' => $E_CRITICAL,
  'out' => "C: LUN foobar_postgresql_lun0: less than 2 paths (0/4)!;W: LUN foobar_postgresql_lun0, path -: ERROR.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 22", 'ret' => $E_WARNING,
  'out' => "W: LUN tex-lun4: less than 4 paths (2/4).;W: LUN tex-lun3: less than 4 paths (2/4).;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 23", 'ret' => $E_WARNING,
  'out' => "W: LUN 1STORAGE_server_target2: less than 4 paths (2/4).;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 24", 'ret' => $E_CRITICAL,
  'out' => "C: LUN 1STORAGE_server_target2: less than 2 paths (1/4)!;W: LUN 1STORAGE_server_target2, path sdd: ERROR.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 25", 'ret' => $E_OK,
  'out' => "O: LUN dm-2: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 26", 'ret' => $E_CRITICAL,
  'out' => "C: LUN map00: less than 2 paths (1/4)!;W: LUN map00, path sdf: ERROR.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 27", 'ret' => $E_CRITICAL,
  'out' => "C: LUN map00: less than 2 paths (1/4)!;W: LUN map00: missing path (empty path name);"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 28", 'ret' => $E_OK,
  'out' => "O: LUN fc-p6-vicepb: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 29", 'ret' => $E_WARNING,
  'out' => "W: LUN mpathb: less than 4 paths (3/4).;W: LUN mpatha: less than 4 paths (2/4).;W: LUN mpatha, path sdi: ERROR.;W: LUN mpatha, path sdc: ERROR.;W: LUN mpathb, path sdj: ERROR.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 30", 'ret' => $E_WARNING,         # 30
  'out' => "W: LUN mpatha: less than 4 paths (3/4).;W: LUN mpatha, path sddv: ERROR.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31", 'ret' => $E_CRITICAL,         # 31  no group, no extra
  'out' => "C: LUN dm-1: less than 2 paths (1/4)!;O: LUN dm-13: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -g IBM,ServeRAID,1,1:HAL,ChpRAID,1,2:", 'ret' => $E_OK,         # 32 group matches => OK
  'out' => "O: LUN dm-13: 4/4.;O: LUN dm-1: 1/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -g IBM,ServeRAID,4,8:HAL,ChpRAID,1,2:", 'ret' => $E_CRITICAL,   # 33 group matches => CRITICAL
  'out' => "C: LUN dm-1: less than 4 paths (1/8)!;O: LUN dm-13: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -g IBM,ServeRAID,4,8:HAL,ChpRAID,1,2: -e dm-1,1,1,critical:", 'ret' => $E_OK,         # 34 group matches, extraconfig matches => OK via extraconfig
  'out' => "O: LUN dm-13: 4/4.;O: LUN dm-1: 1/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -g IBM,ServeRAID,1,1:HAL,ChpRAID,1,2: -e godot,1,1,critical:", 'ret' => $E_CRITICAL,  # 35 LUN in extraconfig missing => CRITICAL
  'out' => "C: NO DATA found for extra-config LUN selector 'G!godot';O: LUN dm-13: 4/4.;O: LUN dm-1: 1/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 19 -p DW", 'ret' => $E_WARNING,        # 36 Print name changed to WWID, dm-ID not present
  'out' => "W: LUN 36005076801810523100000000000006f, path sdj: NOT active.;W: LUN 36005076801810523100000000000006f, path sdh: ERROR.;W: LUN 36005076801810523100000000000006f, path sde: ERROR.;O: LUN 36005076801810523100000000000006f: 5/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 19 -p D", 'ret' => $E_WARNING,         # 37 Print name default "generic", dm-ID not present
  'out' => "W: LUN MYVOLUME, path sdj: NOT active.;W: LUN MYVOLUME, path sdh: ERROR.;W: LUN MYVOLUME, path sde: ERROR.;O: LUN MYVOLUME: 5/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -e 'W!3600507606700440c1d0bba930b81dd65,1,2,critical:' -p WD", 'ret' => $E_WARNING,         # 38 extraconfig selector WWID, print WWID
  'out' => "W: LUN 3600507606700440c1d0bba930b81dd65: less than 2 paths (1/2).;O: LUN 360050768018106d97800000000000134: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -e 'W!3600507606700440c1d0bba930b81dd65,1,2,critical:' -p D", 'ret' => $E_WARNING,          # 39 extraconfig selector WWID, print dm
  'out' => "W: LUN dm-1: less than 2 paths (1/2).;O: LUN dm-13: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -e 'W!3600507606700440c1d0bbaxxxxxxxxx5,1,2,critical:' -p D", 'ret' => $E_CRITICAL,         # 40 extraconfig selector WWID, print dm, no data for conf
  'out' => "C: NO DATA found for extra-config LUN selector 'W!3600507606700440c1d0bbaxxxxxxxxx5';C: LUN dm-1: less than 2 paths (1/4)!;O: LUN dm-13: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 1 -e 'D!dm-2,3,5:' -p D", 'ret' => $E_CRITICAL,         # 41 Attribs (1)
  'out' => "C: LUN dm-2: less than 3 paths (2/5)!;O: LUN dm-19: 2/1.;O: LUN dm-3: 4/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 1 -e 'D!dm-2,1,2:' -p D", 'ret' => $E_OK,               # 42 Attribs (2)
  'out' => "O: LUN dm-3: 4/1.;O: LUN dm-2: 2/2.;O: LUN dm-19: 2/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 1 -e 'W!3600a098038303039365d4671616a756e,3,5:' -p D", 'ret' => $E_CRITICAL,        # 43 Attribs (3)
  'out' => "C: LUN dm-2: less than 3 paths (2/5)!;O: LUN dm-19: 2/1.;O: LUN dm-3: 4/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 1 -e 'W!3600a098038303039365d4671616a756e,1,2:' -p D", 'ret' => $E_OK,              # 44 Attribs (4)
  'out' => "O: LUN dm-3: 4/1.;O: LUN dm-2: 2/2.;O: LUN dm-19: 2/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 1 -e 'W!3600a098038303039365d4671616a756e,1,2:' -p D", 'ret' => $E_OK,              # 45 Attribs (5)
  'out' => "O: LUN dm-3: 4/1.;O: LUN dm-2: 2/2.;O: LUN dm-19: 2/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 19 --addchecks sh,2,4,si,1,2 --scsi-all", 'ret' => $E_WARNING,              # 46 MIT scsi-all
  'out' => "W: LUN MYVOLUME: less than 4 scsi-hosts (2/4).;W: LUN MYVOLUME, path sdj: NOT active.;W: LUN MYVOLUME, path sdh: ERROR.;W: LUN MYVOLUME, path sde: ERROR.;O: LUN MYVOLUME: 5/4.;O: LUN MYVOLUME: scsi-ids 4/2.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 19 --addchecks sh,2,4,si,1,2", 'ret' => $E_WARNING,                         # 47 OHNE scsi-all
  'out' => "W: LUN MYVOLUME: less than 4 scsi-hosts (2/4).;W: LUN MYVOLUME, path sdj: NOT active.;W: LUN MYVOLUME, path sdh: ERROR.;W: LUN MYVOLUME, path sde: ERROR.;O: LUN MYVOLUME: 5/4.;O: LUN MYVOLUME: scsi-ids 3/2.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -e 'D!dm-3,2,4,warning,p,0,0,sh,2,4,si,1,2:'", 'ret' => $E_WARNING,       # 48 scsi extraconf
  'out' => "W: LUN dm-3: less than 2 scsi-ids (1/2).;W: LUN dm-2: less than 4 paths (2/4).;W: LUN dm-19: less than 4 paths (2/4).;O: LUN dm-3: scsi-hosts 4/4.;O: LUN dm-3: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -g IBM,ServeRAID,1,1@#,p,0,0,sh,0,0,si,0,0:HAL,ChpRAID,1,2@#,sh,0,0,si,0,0: --addchecks sh,1,2,si,1,2", 'ret' => $E_OK,  # 49 group matches => OK, different scsi rules for group
  'out' => "O: LUN dm-13: scsi-ids 2/2.;O: LUN dm-13: scsi-hosts 2/2.;O: LUN dm-13: 4/4.;O: LUN dm-1: 1/1.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 2 -e 'D!dm-3,2,4,warning,p,0,0,sh,2,4,si,0,0:' -p D --addchecks sh,1,2,si,0,0", 'ret' => $E_OK,              # 50 Attribs (2), scsi-def in extraconfig, scsi opt
  'out' => "O: LUN dm-3: scsi-hosts 4/4.;O: LUN dm-3: 4/4.;O: LUN dm-2: scsi-hosts 2/2.;O: LUN dm-2: 2/2.;O: LUN dm-19: scsi-hosts 2/2.;O: LUN dm-19: 2/2.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 2 -e 'D!dm-3,2,4,warning,p,0,0,sh,2,4,si,0,0:' -p D", 'ret' => $E_OK,                                   # 51 Attribs (2), scsi-def in extraconfig
  'out' => "O: LUN dm-3: scsi-hosts 4/4.;O: LUN dm-3: 4/4.;O: LUN dm-2: 2/2.;O: LUN dm-19: 2/2.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 2 -e 'D!dm-3,2,4,warning,p,0,0,sh,2,4,si,0,0:' -p D --addchecks sh,1,2,si,1,2", 'ret' => $E_WARNING,         # 52 Attribs (2), scsi-def in extraconfig, scsi opt
  'out' => "W: LUN dm-2: less than 2 scsi-ids (1/2).;W: LUN dm-19: less than 2 scsi-ids (1/2).;O: LUN dm-2: scsi-hosts 2/2.;O: LUN dm-3: scsi-hosts 4/4.;O: LUN dm-3: 4/4.;O: LUN dm-2: 2/2.;O: LUN dm-19: scsi-hosts 2/2.;O: LUN dm-19: 2/2.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 32 -m 1 -o 2 -e 'D!dm-3,2,4,warning,p,0,0,sh,2,4,si,0,0:' -p D --addchecks sh,1,2,si,1,2,p,1,2", 'ret' => $E_WARNING, # 53 Attribs (2), scsi-def in extraconfig, scsi opt, policies
  'out' => "W: LUN dm-2: less than 2 scsi-ids (1/2).;W: LUN dm-19: less than 2 scsi-ids (1/2).;O: LUN dm-2: scsi-hosts 2/2.;O: LUN dm-3: scsi-hosts 4/4.;O: LUN dm-3: 4/4.;O: LUN dm-19: scsi-hosts 2/2.;O: LUN dm-19: policies 2/2.;O: LUN dm-19: 2/2.;O: LUN dm-2: policies 2/2.;O: LUN dm-2: 2/2.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 31 -g IBM,ServeRAID,1,1,p,0,0,sh,0,0,si,0,0:HAL,ChpRAID,1,2,sh,0,0,si,0,0: --addchecks sh,1,2,si,1,2,p,1,2", 'ret' => $E_CRITICAL,  # 54 group matches, different scsi rules for group, policies
  'out' => "C: LUN dm-1: less than 2 paths (1/4)!;W: LUN dm-1: less than 2 policies (1/2).;W: LUN dm-1: less than 2 scsi-ids (1/2).;W: LUN dm-1: less than 2 scsi-hosts (1/2).;O: LUN dm-13: scsi-ids 2/2.;O: LUN dm-13: scsi-hosts 2/2.;O: LUN dm-13: policies 2/2.;O: LUN dm-13: 4/4.;"
},
{ 'cmd' => "./check-multipath.pl -l ';' -t -M -v -S -d 8 -p DW", 'ret' => $E_CRITICAL,  # 55 output check, LUN print name 
  'out' => "C: LUN dm-1: less than 2 paths (1/4)!;C: LUN dm-0: less than 2 paths (1/4)!;W: LUN dm-0, path sde: ERROR.;W: LUN dm-0, path sdc: ERROR.;W: LUN dm-1, path sdk: NOT active.;W: LUN dm-1, path sdh: ERROR.;W: LUN dm-1, path sdf: ERROR.;"
},
    );

my $testcaseCount = scalar( @testDefinitions );



# Usage text
my $USAGE = <<"END_USAGE";

Usage: $NAME [OPTION]...
END_USAGE



# Help text
my $HELP = <<"END_HELP";

$NAME   $VERSION

    Call testcases included in check-multipath.pl (in current directory)
    and compare output with expected results.

    Put this script in the same directory as check-multipath.pl 
    and call ./TEST_check-multipath.pl

    ALWAYS USE VERSIONS OF THE TWO SCRIPTS WITH IDENTICAL VERSION CODES!

see:
 http://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check-2Dmultipath-2Epl/details

OPTIONS:

  -h, --help          Display this help text
  -V, --version       Display version info
  -v, --verbose

END_HELP


# Version and license text
my $LICENSE = <<"END_LICENSE";

$NAME   $VERSION

Copyright (C) 2013-2015 $AUTHOR
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by
$AUTHOR <$CONTACT>

END_LICENSE




# Options with default values
my %opt
  = ( 'help'          => 0,
      'version'       => 0,
      'verbose'       => 0,
      'test'          => 0, 
    );


# Get options
GetOptions('h|help'           => \$opt{help},
	   'V|version'        => \$opt{version},
	   'v|verbose'        => \$opt{verbose},
	  ) or do { print $USAGE; exit 3 };


# If user requested help
if ($opt{'help'}) {
    print $USAGE, $HELP;
    exit 0;
}

# If user requested version info
if ($opt{'version'}) {
    print $LICENSE;
    exit 0;
}

#=====================================================================

#---------------------------------------------------------------------
# Functions
#---------------------------------------------------------------------


#---------------------------------------
# print text for returncode if defined
sub printRc {
    my ($rc) = @_;
    if (defined ($reverse_exitcode{$rc}) ) {
	return $reverse_exitcode{$rc};
    } else {
	return "#$rc#";
    } # if    
} # sub

#=====================================================================



my $expectedVersion = '';
if ( $VERSION =~ m!^([\d\.]+)! ) {
    $expectedVersion = $1;
} else {
    print "INTERNAL ERROR: malformed version string '$VERSION'\n";
    exit 6;
} 


my $command = './check-multipath.pl -V';
my $gotResult =  qx($command);
my $pluginVersion = '';
if ($gotResult =~ m!check-multipath.pl\s+([\d\.]+)\s+\d+\.\s+\w+\.?\s+\d+\n!) {
    $pluginVersion = $1;
}

if ($pluginVersion ne $expectedVersion) {
    print "\nERROR : version mismatch or error calling plugin.\n\n";
    print "GOT     : '$pluginVersion'\n";
    print "EXPECTED: '$expectedVersion'\n\n";
    print "Plugin output was:\n";
    print "==================\n";
    print "[$gotResult]\n\n";
    exit 5;
}


my $ret         = 0;

my $di          = 0;
my $failedCount = 0;
foreach my $rTestDefinition (@testDefinitions) {

    $di++;

    my $command        = $$rTestDefinition{'cmd'};
    my $expectedRc     = $$rTestDefinition{'ret'};
    my $expectedResult = $$rTestDefinition{'out'};

    $gotResult =  qx($command);
    my $gotRc = $?;
    if ($gotRc != -1) {
	$gotRc = $gotRc >> 8;
    }

    my $failed =  ($gotResult ne $expectedResult) || ($expectedRc != $gotRc);

    if (!$failed) {
	if ($opt{'verbose'}) {
	    print "# $di OK\n$command\n$gotResult\n[".$reverse_exitcode{$expectedRc}."]\n\n";
	} else {
	    print "$di ";
	    if ( ($di % 20) ==0  ) {
		print "\n";
	    } # if 
	} # if
    } else {
	print "\n";
	if ($opt{'verbose'}) {
	    print "=============================\n";
	    print "# $di FAILED! ##\n";
	    print "# command: $command\n";
	} else {
	    print "# $di FAILED!\n";
	}

	if ($gotResult ne $expectedResult) {
	    print "GOT:\n'$gotResult'\n\n";
	    print "EXPECTED:\n'$expectedResult'\n";
	    if  ($expectedRc != $gotRc) {
		print "\n";
	    }
	} # if

	if  ($expectedRc != $gotRc) {
	    print "EXPECTED RETURNCODE '$expectedRc' [".printRc($expectedRc)."]\n";
            print "     GOT RETURNCODE '$gotRc' ["     . printRc($gotRc)    ."]\n";
	} # if


	if ($opt{'verbose'}) {
	    print "=============================\n";
	}
	print "\n";
	$ret = 1;
	$failedCount++;
    } # if
   
} # foreach


if ($failedCount > 0){
    print "\n$failedCount of $testcaseCount testcases FAILED\n";
    if ($opt{'verbose'}) {
	print "=============================\n";
    }
    print "\n";
} else {
    print "[All $testcaseCount testcases OK]\n\n";
} # if

exit $ret;
