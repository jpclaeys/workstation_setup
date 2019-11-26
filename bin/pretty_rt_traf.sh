START=`./rt_traf.sh $1`;
IN_START=`echo $START | awk '{ print $1 }'`; OUT_START=`echo $START | awk '{ print $2 }'`;
sleep 10;
END=`./rt_traf.sh $PID`; IN_END=`echo $END | awk '{ print $1 }'`; 
OUT_END=`echo $END | awk '{ print $2 }'`; 
IN_BPS=`echo "scale=2; (($IN_END-$IN_START)/10)/8" | bc`; 
OUT_BPS=`echo "scale=2; (($OUT_END-$OUT_START)/10)/8" | bc`; 
echo "In: " $IN_BPS "Bits/second"; 
echo "Out: " $OUT_BPS "Bits/second"
