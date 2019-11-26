
A variable modified inside a while loop is not remembered


https://stackoverflow.com/questions/16854280/a-variable-modified-inside-a-while-loop-is-not-remembered

Redirect to a file handle explicitly (Mind the space in < <!):

exec 3< <(echo -e  $lines)
while read -u 3 line; do
...
done


tmp
SRCFILE=cluster231_softinst.tab
DESTFILE=cluster236_softinst.orig
MISSING=0
exec 3< <(cat $SRCFILE); while read -u 3 line ; do [[ `grep -c "$line" $DESTFILE` -eq 0 ]] && echo "Missing entry in target: $line" && ((MISSING++));done
[ "$MISSING" -eq 0 ] &&  echo "No missing entry in destination, no merge required" && return 1




