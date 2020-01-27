#!/bin/bash

#reading args
expname=$1
year=$2

#usage
if [ $# -lt 2 ]
then
  echo "Usage:   ./ifs_daily.sh EXP YEAR"
  echo "Example: ./ifs_daily.sh io01 1990"
  exit 1
fi

# temp working dir, within $TMPDIR so it is automatically removed
mkdir -p ${ECE3_POSTPROC_TMPDIR}
WRKDIR=$(mktemp -d ${ECE3_POSTPROC_TMPDIR}/hireclim2_${expname}_XXXXXX) # use template if debugging
cd $WRKDIR

NPROCS=${IFS_NPROCS:-12}

# update IFSRESULTS and get OUTDIR0
eval_dirs 1

# where to save (archive) the results
OUTDIR=$OUTDIR0/day/Post_$year
mkdir -p $OUTDIR || exit -1

echo --- Analyzing daily output -----
echo Temporary directory is $WRKDIR
echo Data directory is $IFSRESULTS
echo Postprocessing with $NPROCS cores
echo Postprocessed data directory is $OUTDIR

# output filename root
out=$OUTDIR/${expname}_${year}


#spectral variables
for m1 in $(seq 1 $NPROCS 12)
do
   for m in $(seq $m1 $((m1+NPROCS-1)) )
   do
      ym=$(printf %04d%02d $year $m)
      eval_dirs $m
      $cdo -t $ecearth_table -b F64 splitvar -sp2gpl \
          -settime,12:00:00 -daymean -sellevel,100000,85000,70000,50000,30000,10000,5000,1000 -selvar,t,u,v,z -shifttime,-1hour \
          $IFSRESULTS/ICMSH${expname}+$ym icmsh_${ym}_day_ &
   done
   wait
done

#concatenate t u v z
for v in t u v z
do
   rm -f ${out}_${v}_day.nc
   $cdozip -r -t $ecearth_table cat icmsh_??????_day_$v.grb ${out}_${v}_day.nc

done

#precipitation and surface temperature
for v in lsp cp tas ; do
  for m1 in $(seq 1 $NPROCS 12)
  do
     for m in $(seq $m1 $((m1+NPROCS-1)) )
     do
       ym=$(printf %04d%02d $year $m)
       eval_dirs $m
       $cdo -t $ecearth_table -b F64 selvar,${v} -daymean -shifttime,-1hour \
           $IFSRESULTS/ICMGG${expname}+$ym icmgg_${ym}_day_${v}.grb &
   done
   wait
done
done

#concatenate and store
for v in tas ; do
     rm -f ${out}_${v}_day.nc
     $cdozip -R -r -t $ecearth_table cat icmgg_${year}??_day_${v}.grb ${out}_${v}_day.nc
done

for v in lsp cp ; do
     rm -f ${v}_day.grb
     $cdo -r -t $ecearth_table cat icmgg_${year}??_day_${v}.grb ${v}_day.grb
done

#  post-processing timestep in seconds
eval_dirs 1
pptime=$($cdo showtime -seltimestep,1,2 $IFSRESULTS/ICMGG${expname}+${year}01 | \
   tr -s ' ' ':' | awk -F: '{print ($5-$2)*3600+($6-$3)*60+($7-$4)}' )

# precip and evap and runoff in kg m-2 s-1
$cdo -b F32 -t $ecearth_table setparam,228.128 -mulc,1000 -divc,$pptime -add lsp_day.grb cp_day.grb tmp_totp_day.grb
$cdozip -r -R -t $ecearth_table copy tmp_totp_day.grb ${out}_totp_day.nc

# change file suffices
( cd $OUTDIR ; for f in $(ls *.nc4); do mv $f ${f/.nc4/.nc}; done )

set -x
rm $WRKDIR/*.grb
cd -
rmdir $WRKDIR
set +x
