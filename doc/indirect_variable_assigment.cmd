Indirect variable assignment in bash

Seems that the recommended way of doing indirect variable setting in bash is to use eval:

var=x; val=foo
eval $var=$val
echo $x  # --> foo


Example:

ZPOOLS=`cat ${tmp_folder}/zpool_list.txt` && echo $ZPOOLS
{
# Define the POOLx variables
#-----------------------------
idx=0 && for i in $ZPOOLS; do
  ((idx++)) ;  var=POOL${idx} && var_old=${var}_OLD && eval $var=$i && eval $var_old=${i}_old
  printf "%-12s= %s\n" $var ${!var}
  printf "%-12s= %s\n" $var_old ${!var_old}
done
}


POOL1     = sisyphe-dz-data
POOL1_OLD = sisyphe-dz-data_old
POOL2     = sisyphe-dz-db
POOL2_OLD = sisyphe-dz-db_old

