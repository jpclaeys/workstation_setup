#!/usr/bin/ksh

#

# zvmstat - print vmstat style info per Zone.

#           This uses DTrace (Solaris 10 3/05).

#

# This program must be run from the global zone as root.

#

# 08-Jan-2006, ver 0.63         (check for newer versions)

#

# USAGE: 	zvmstat [-ht] [interval [count]]

#

#		zvmstat         # default output

#			-t      # print times

#  eg,

#		zvmstat 1       # print every 1 second

#		zvmstat 10 5    # print 5 x 10 second samples

#		zvmstat -t 5    # print every 5 seconds with time

#

#

# FIELDS:

#		re		page reclaims

#		mf		minor faults

#		fr		pages freed

#		sr		scan rate

#		epi		executable pages paged in

#		epo		executable pages paged out

#		epf		executable pages freed

#		api		anonymous pages paged in

#		apo		anonymous pages paged out

#		apf		anonymous pages freed

#		fpi		filesystem pages paged in

#		fpo		filesystem pages paged out

#		fpf		filesystem pages freed

#

# NOTES: 

# - Zone status should really be provided by Kstat, which currently

#   provides system wide values, per CPU and per processor set, but not per

#   zone. DTrace can fill this role in the meantime until Kstat supports zones.

# - First output does not contain summary since boot.

#

# SEE ALSO: prstat -Z

#

# COPYRIGHT: Copyright (c) 2005 Brendan Gregg.

#

# CDDL HEADER START

#

#  The contents of this file are subject to the terms of the

#  Common Development and Distribution License, Version 1.0 only

#  (the "License").  You may not use this file except in compliance

#  with the License.

#

#  You can obtain a copy of the license at Docs/cddl1.txt

#  or http://www.opensolaris.org/os/licensing.

#  See the License for the specific language governing permissions

#  and limitations under the License.

#

# CDDL HEADER END

#

# BUGS:

# - First output may not contain all zones due to how loops are achieved.

#   Check for newer versions.

#

# Author: Brendan Gregg  [Sydney, Australia]

#

# 11-May-2005   Brendan Gregg   Created this.

# 26-Jul-2005	   "      "	Improved code.

#





##############################

# --- Process Arguments ---

#



### default variables

opt_time=0; interval=1; counts=1



### process options

while getopts ht name

do

	case $name in

	t)      opt_time=1 ;;

	h|?)    cat <<-END >&2

		USAGE: zvmstat [-ht] [interval [count]]

		       zvmstat         # default output

		               -t      # print times

		   eg,

		       zvmstat 1       # print every 1 second

		       zvmstat 10 5    # print 5 x 10 second samples

		       zvmstat -t 5    # print every 5 seconds with time

		END

		exit 1

	esac

done

shift $(( OPTIND - 1 ))



### option logic

if (( "0$1" > 0 )); then

        interval=$1; counts=-1; shift

fi

if (( "0$1" > 0 )); then

        counts=$1; shift

fi





#################################

# --- Main Program, DTrace ---

#

dtrace -n '

 #pragma D option quiet

 #pragma D option destructive

 #pragma D option switchrate=10



 /*

  * Command line arguments

  */

 inline int OPT_time   = '$opt_time';

 inline int INTERVAL   = '$interval';

 inline int COUNTER    = '$counts';



 /* 

  * Initialise variables

  */

 dtrace:::BEGIN 

 {

	secs = INTERVAL; 

	counts = COUNTER;

	zonemax = 0;

	listing = 1;

	re[""] = 0; pi[""] = 0; po[""] = 0;

	mf[""] = 0; sr[""] = 0; fr[""] = 0;

	epi[""] = 0; epo[""] = 0; epf[""] = 0;

	api[""] = 0; apo[""] = 0; apf[""] = 0;

	fpi[""] = 0; fpo[""] = 0; fpf[""] = 0;

 }



 /*

  * Build zonelist array

  *

  * Here we want the output of a command to be saved into an array

  * inside dtrace. This is done by running the command, sending the

  * output to /dev/null, and by probing its write syscalls from dtrace. 

  *

  * This is an example of a "scraper".

  */



 /*

  * List zones

  */

 dtrace:::BEGIN 

 {

	/* run zoneadm */

	system("/usr/sbin/zoneadm list > /dev/null; echo END > /dev/null");

 }



 /*

  * Scrape zone listing

  */

 syscall::write:entry

 /listing && (execname == "zoneadm") && 

 (curthread->t_procp->p_parent->p_ppid == $pid)/

 {

	/* read zoneadm output */

	zonelist[zonemax] = stringof(copyin(arg1, arg2 - 1));



	/* increment max number of zones */

	zonemax++;

 }



 /*

  * Finish scraping zones

  */

 syscall::write:entry

 /listing && (execname == "sh") && (ppid == $pid)/

 {

	/*

	 * this end tag lets us know our zonelist has finished.

	 * thanks A. Packer.

	 */

	listing = stringof(copyin(arg1, arg2 - 1)) == "END" ? 0 : 1;

 }



 /*

  * Record vminfo counters

  */

 vminfo:::pgrec      { re[zonename] += arg0; }

 vminfo:::as_fault   { mf[zonename] += arg0; }

 vminfo:::scan       { sr[zonename] += arg0; }

 vminfo:::execpgin   { epi[zonename] += arg0; }

 vminfo:::execpgout  { epo[zonename] += arg0; }

 vminfo:::execfree   { epf[zonename] += arg0; fr[zonename] += arg0; }

 vminfo:::anonpgin   { api[zonename] += arg0; }

 vminfo:::anonpgout  { apo[zonename] += arg0; }

 vminfo:::anonfree   { apf[zonename] += arg0; fr[zonename] += arg0; }

 vminfo:::fspgin     { fpi[zonename] += arg0; }

 vminfo:::fspgout    { fpo[zonename] += arg0; }

 vminfo:::fsfree     { fpf[zonename] += arg0; fr[zonename] += arg0; }



 /*

  * Timer

  */

 profile:::tick-1sec

 {

	secs--;

 }



 /*

  * Check for exit

  */

 profile:::tick-1sec

 /counts == 0/

 {

	exit(0);

 }



 /*

  * Print header line

  */

 profile:::tick-1sec

 /secs == 0/

 {

	/* set counters */

	secs = INTERVAL;

	counts--;

	zonei = 0;



	/* print time */

	OPT_time ? printf("\n%Y,\n",walltimestamp) : 1;



	/* print output line */

	printf("%10s %4s %5s %4s %5s %4s %4s %4s %4s %4s %4s %4s %4s %4s\n",

	    "ZONE", "re", "mf", "fr", "sr", "epi", "epo", "epf", "api", "apo",

	    "apf", "fpi", "fpo", "fpf");



	/* ensure zone writes are triggered */

	printf(" \b");

 }



 /*

  * Print zone status line

  *

  * This is a fairly interesting function in that it loops over the keys in 

  * an associative array and prints out the values. DTrace cant really do 

  * loops, and generally doesnt need to. We "cheat" by generating writes

  * in the above probe which in turn trigger the probe below which 

  * contains the contents of each loop. Dont do this at home! We are

  * supposed to use aggreagations instead, wherever possible.

  *

  * This is an example of a "feedback loop".

  */

 syscall::write:return

 /pid == $pid && zonei < zonemax/

 {

	/* fetch zonename */

	self->zone = zonelist[zonei];



	/* print output */

	printf("%10s %4d %5d %4d %5d %4d %4d %4d %4d %4d %4d %4d %4d %4d\n",

	    self->zone, re[self->zone], mf[self->zone], fr[self->zone],

	    sr[self->zone], epi[self->zone], epo[self->zone],

	    epf[self->zone], api[self->zone], apo[self->zone],

	    apf[self->zone], fpi[self->zone], fpo[self->zone],

	    fpf[self->zone]);

	

	/* clear values */

	re[self->zone] = 0; mf[self->zone] = 0; fr[self->zone] = 0;

	sr[self->zone] = 0; epi[self->zone] = 0; epo[self->zone] = 0;

	epf[self->zone] = 0; api[self->zone] = 0; apo[self->zone] = 0;

	apf[self->zone] = 0; fpi[self->zone] = 0; fpo[self->zone] = 0;

	fpf[self->zone] = 0;

	self->zone = 0;

	

	/* go to next zone */

	zonei++;

 }

'
