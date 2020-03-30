#!/bin/bash
set -e

 ############################################
 # To be called from ../master_hiresclim.sh #
 ############################################

# This is the number of months in a leg. Only 1 and 12 tested yet.
mlegs=${months_per_leg}
#if [[ $mlegs != 12 && $mlegs != 1 ]]
if [[ $mlegs != 12 ]]
then
    echo "*EE* only yearly leg has been tested in C-CYCLE postprocessing. Please review."
    exit 1
fi

# reading args
expname=$1
year=$2
yref=$3

# usage
if [ $# -lt 3 ]
then
  echo "Usage:   ./ccycle_post.sh EXP YEAR YEAR_REF"
  echo "Example: ./ccycle_post.sh io01 1990 1950"
  exit 1
fi

# temp working dir, within $TMPDIR so it is automatically removed or use XXXX template if debugging
mkdir -p ${TEMPDIR}
WRKDIR=$(mktemp -d ${TEMPDIR}/hireclim2_${expname}_XXXXXX) # use template if debugging
cd $WRKDIR

# update NEMORESULTS and get OUTDIR0
eval_dirs 1

# where to save (archive) the results
OUTDIR=$OUTDIR0/mon/Post_$year
mkdir -p $OUTDIR || exit -1

# output filename root
out=$OUTDIR/${expname}_${year}

avars=""
[ ${ccycle_lpjg} == 1 ] && avars+=" cLand"
[ ${ccycle_tm5} == 1 ] && avars+=" co2 co2mass"

# for PISCES - special treatment of ocean.carbon
if [ ${ccycle_pisces} == 1 ] ; then
    #$python $PROGDIR/script/ocean_carbon_csv2nc.py ${ECE3_POSTPROC_RUNDIR}/ocean.carbon ${out}_ocean_carbon.nc
    cp ${ECE3_POSTPROC_RUNDIR}/ocean.carbon ${out}_ocean.carbon
fi

for cvar in ${avars[*]}; do

    rm -f tmp?.nc area.nc weights.nc

    if [ $cvar = "cLand" ] ; then
        cmor_table="Emon"
        oper="fldsum"
    elif [ $cvar = "co2" ] ; then
        cmor_table="Amon"
        oper="fldmean"
    elif [ $cvar = "co2mass" ] ; then
        cmor_table="Amon"
        oper="none"
    else
        echo "undefined var $cvar"
        exit 1
    fi
    cmor_dir=$( echo $CMORRESULTS/*/*/*/*/*/${cmor_table}/${cvar}/*/* )
    cmor_file=$( cd ${cmor_dir} && ls ${cvar}_${cmor_table}_*_${year}01-${year}12.nc )

    if [ $cvar = "co2" ] ; then
       $cdo setctomiss,nan ${cmor_dir}/${cmor_file} ${cmor_file}
    else
       cp ${cmor_dir}/${cmor_file} .
    fi

    if [ $oper = "fldsum" ] ; then
        $cdo -f nc gridarea ${cmor_file} area.nc
        $cdo mul area.nc ${cmor_file} tmp1.nc
        $cdo fldsum tmp1.nc tmp2.nc
    elif [ $oper = "fldmean" ] ; then
        #$cdo -f nc gridweights ${cmor_file} weights.nc
        $cdo fldmean ${cmor_file} tmp2.nc
    else
        cp ${cmor_file} tmp2.nc
    fi

    # setup time dimension
    $cdo -R settunits,hours -settime,0 -setday,1 tmp2.nc tmp3.nc
    mv tmp3.nc ${out}_${cvar}.nc

    if [ $cvar = "co2" ] ; then
        #cdo chvar,co2,co2s -sellevel,100000 ${out}_${cvar}.nc ${out}_co2s.nc
        $cdo chvar,co2,co2s -sellevel,92500 ${out}_${cvar}.nc ${out}_co2s.nc
    fi

    rm -f tmp?.nc area.nc weights.nc

done

cd -
rm -rf $WRKDIR
