#!/bin/bash
set -e

set -xuve

 ############################################
 # To be called from ../master_hiresclim.sh #
 ############################################

mlegs=${monthly_leg}  # env variable (1 if using monthly legs, 0 yearly)

expname=$1
year=$2
yref=$3

#usage
if [ $# -lt 3 ]
then
  echo "Usage:   ./ifs_monthly.sh EXP YEAR"
  echo "Example: ./ifs_monthly.sh io01 1990"
  exit 1
fi

# temp working dir, within $TMPDIR so it is automatically removed
WRKDIR=$(mktemp -d $SCRATCH/tmp_ecearth3/post_hireclim2_XXXXXX) # use template if debugging
cd $WRKDIR

# where to get the files, assuming yearly legs
IFSRESULTS=$BASERESULTS/ifs/$(printf %03d $((year-${yref}+1)))

NPROCS=${IFS_NPROCS}

# where to save (archive) the results
OUTDIR=$OUTDIR0/mon/Post_$year
echo $OUTDIR
mkdir -p $OUTDIR || exit -1

# output filename root
out=$OUTDIR/${expname}_${year}

# filter codes listed in ecearth-tab
selcode_str="selcode"
for code in `awk '{print $1}' $ecearth_table` ; do selcode_str+=,$code ; done

#filtering out primavera 3h output, need to load grib_api
#TODO merge this script with ifs_monthly.sh
#TODO check for any useless variables in GG files e.g. istl?, swvl?
module unload eccodes
module load grib_api/1.12.3
filter=${WRKDIR}/ifs_monthly_prim_filter
cat > $filter << EOT
if ( dataTime == 0 || dataTime == 600 || dataTime == 1200 || dataTime == 1800 )
{
  if ( ( ( gridType is "reduced_gg" ) || ( gridType is "sh" ) ) && ( ! ( levelType is "ml" ) ) && ( ! ( levelType is "pv" ) ) )
  {
    if ( levelType is "pl" )
    {
      if ( ( level == 1000 ) || ( level == 925 ) || ( level == 850 ) || ( level == 700 ) || ( level == 500) || ( level == 400 ) || ( level == 300 ) || ( level == 200 ) || ( level == 100 ) || ( level == 50 ) || ( level == 10 ) )
      {
        write;
      }
    }
    else
    {
      write;
    }
  }
}
EOT

# ICMSH
if  (( do_3d_vars ))
then
for m1 in $(seq 1 $NPROCS 12)
do
   for m in $(seq $m1 $((m1+NPROCS-1)) )
   do
      ym=$(printf %04d%02d $year $m)
      (( $mlegs )) && IFSRESULTS=$BASERESULTS/ifs/$(printf %03d $(( (year-${yref})*12+m)))
#      $cdo -b F64 -t $ecearth_table splitvar -sp2gpl \
#         -setdate,$year-$m-01 -settime,00:00:00 -timmean \
#         $IFSRESULTS/ICMSH${expname}+$ym icmsh_${ym}_ &
      (
      grib_filter -o icmsh${expname}+$ym.grb ${filter} $IFSRESULTS/ICMSH${expname}+$ym
      $cdo -b F32 -t $ecearth_table splitvar -sp2gpl \
          -setdate,$year-$m-01 -settime,00:00:00 -timmean \
	  -selcode,129,130,131,132,152 \
         icmsh${expname}+$ym.grb icmsh_${ym}_ 
#	  -sellevel,100000,92500,85000,70000,50000,40000,30000,20000,10000,5000,1000 \
      ) &
   done
   wait
done

for v in t u v z lnsp
do
   rm -f ${out}_${v}.nc
   $cdozip -r -R -t $ecearth_table cat icmsh_??????_$v.grb ${out}_${v}.nc
done

#part on surface pressure
$cdo chcode,152,134 ${out}_lnsp.nc temp_lnsp.nc
$cdo -t $ecearth_table exp temp_lnsp.nc ${out}_sp.nc
rm temp_lnsp.nc

fi # do_3d_vars


# ICMGG

for m1 in $(seq 1 $NPROCS 12)
do
   for m in $(seq $m1 $((m1+NPROCS-1)) )
   do
      ym=$(printf %04d%02d $year $m)
      (( $mlegs )) && IFSRESULTS=$BASERESULTS/ifs/$(printf %03d $(( (year-${yref})*12+m)))
#      $cdo -b F64 setdate,$year-$m-01 -settime,00:00:00 -timmean \
#         $IFSRESULTS/ICMGG${expname}+$ym icmgg_${ym}.grb &
       ( 
       grib_filter -o icmgg${expname}+$ym.grb ${filter} $IFSRESULTS/ICMGG${expname}+$ym
       $cdo -b F32 setdate,$year-$m-01 -settime,00:00:00 -timmean -${selcode_str} \
         icmgg${expname}+$ym.grb icmgg_${ym}.grb 
       ) &
   done
   wait
done

#exit 0

rm -f icmgg_${year}.grb
$cdo cat icmgg_${year}??.grb icmgg_${year}.grb

$cdozip -r -R -t $ecearth_table splitvar \
   -selvar,uas,vas,tas,ci,sstk,sd,tds,tcc,lcc,mcc,hcc,tclw,tciw,tcwv,msl,q,fal,uas,vas \
   icmgg_${year}.grb ${out}_


#  post-processing timestep in seconds from first month
#(( $mlegs )) && IFSRESULTS=$BASERESULTS/ifs/$(printf %03d $(( (year-${yref})*12 + 1)))
#pptime=$($cdo showtime -seltimestep,1,2 $IFSRESULTS/ICMGG${expname}+${year}01 | \
#   tr -s ' ' ':' | awk -F: '{print ($5-$2)*3600+($6-$3)*60+($7-$4)}' )
#if [ $pptime -le 0 ]
#then
#   pptime=21600 # default 6-hr output timestep
#fi
#ET TODO find a way to specify pptime when needed, for now it is hard-coded
pptime=10800


# precip and evap and runoff in kg m-2 s-1
$cdozip -R -r -t $ecearth_table mulc,1000 -divc,$pptime -selvar,ro \
   icmgg_${year}.grb ${out}_ro.nc
$cdozip -R -r -t $ecearth_table mulc,1000 -divc,$pptime -selvar,sf \
   icmgg_${year}.grb ${out}_sf.nc
$cdo -t $ecearth_table setparam,228.128 -expr,"totp=1000*(lsp+cp)/$pptime" \
   icmgg_${year}.grb tmp_totp.grb
$cdozip -r -R -t $ecearth_table copy tmp_totp.grb ${out}_totp.nc

#$cdozip -r -R -t $ecearth_table mulc,1000 -divc,$pptime -selvar,e \
#   icmgg_${year}.grb ${out}_e.nc
$cdozip -r -R -t $ecearth_table splitvar -mulc,1000 -divc,$pptime \
 -selvar,e,lsp,cp icmgg_${year}.grb ${out}_
$cdo -R -t $ecearth_table setparam,80.128 -fldmean \
   -expr,"totp=1000*(lsp+cp+e)/$pptime" icmgg_${year}.grb tmp_pme.grb
$cdozip -r -t $ecearth_table copy tmp_pme.grb ${out}_pme.nc

# divide fluxes by PP timestep
$cdozip -r -R -t $ecearth_table splitvar -divc,$pptime \
   -selvar,ssr,str,sshf,ssrd,strd,slhf,tsr,ttr,ewss,nsss,ssrc,strc,tsrc,ttrc \
   icmgg_${year}.grb ${out}_

# net SFC and TOA fluxes
$cdo -R -t $ecearth_table setparam,149.128 -fldmean \
   -expr,"snr=(ssr+str+slhf+sshf)/$pptime" icmgg_${year}.grb tmp_snr.grb
$cdozip -r -t $ecearth_table copy tmp_snr.grb ${out}_snr.nc
$cdo -R -t $ecearth_table setparam,150.128 -fldmean \
   -expr,"tnr=(tsr+ttr)/$pptime" icmgg_${year}.grb tmp_tnr.grb
$cdozip -r -t $ecearth_table copy tmp_tnr.grb ${out}_tnr.nc

# change file suffices
( cd $OUTDIR ; for f in $(ls *.nc4); do mv $f ${f/.nc4/.nc}; done )

set -x
cd -
rm -rf $WRKDIR
set +x
