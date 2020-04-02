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

# define vars to process
monvars="" #monthly files
yearvars="" #yearly files
yearvars2="" #yearly files, obtained from first month of monthly files
yearvars3="" #yearly files, obtained from annual sum of monthly files
if [ ${ccycle_lpjg} == 1 ] ; then
    monvars+=" cLand nbp nep fco2nat fco2antt"
    yearvars+=" cLand cFlux"
    yearvars3+=" nbp nep fco2nat fco2antt"
fi
[ ${ccycle_tm5} == 1 ] && monvars+=" co2 co2mass " && yearvars+=" co2mass" && yearvars2+=" co2s cAtmos"
[ ${ccycle_pisces} == 1 ] && monvars+=" fgco2" && yearvars3+=" fgco2"


# process monthly vars, usually from cmor output

# where to save (archive) the results
OUTDIR=$OUTDIR0/mon/Post_$year
mkdir -p $OUTDIR || exit -1

# output filename root
out=$OUTDIR/${expname}_${year}

# loop over monthly vars
for cvar in ${monvars[*]}; do

    rm -f tmp?.nc area.nc weights.nc

    # define idir, ifile
    cmor_table=""
    oper=""
    idir=""
    ifile=""
    flux=false
    pg_carbon=false
    if [ $cvar = "cLand" ] ; then
        cmor_table="Emon"
        oper="fldsum"
	pg_carbon=true
    elif [ $cvar = "nbp" ] ; then
        cmor_table="Lmon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "nep" ] ; then
        cmor_table="Emon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "fco2nat" ] ; then
        cmor_table="Amon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "fco2antt" ] ; then
        cmor_table="Amon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "fgco2" ] ; then
        cmor_table="Omon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "co2" ] ; then
        cmor_table="Amon"
        oper="fldmean"
    elif [ $cvar = "co2mass" ] ; then
        cmor_table="Amon"
        oper=""
    else
        echo "undefined var $cvar"
        exit 1
    fi
    if [ "${cmor_table}" != "" ] ; then
	idir=$( echo $CMORRESULTS/*/*/*/*/*/${cmor_table}/${cvar}/*/* )
	ifile=$( cd ${idir} && ls ${cvar}_${cmor_table}_*_${year}01-${year}12.nc )
    fi

    if [ "$ifile" = "" ] ; then
	echo "ccycle_post.sh: cannot find input file for variable $cvar !"
	exit 1
    fi

    # copy file (making subset/fix if required)
    if [ $cvar = "co2" ] ; then
	$cdo setctomiss,nan ${idir}/${ifile} ${ifile}
    else
	cp ${idir}/${ifile} .
    fi

    # perform operation
    if [ "$oper" = "fldsum" ] ; then
	$cdo -f nc gridarea ${ifile} area.nc
        #$cdo mul area.nc ${ifile} tmp1.nc
        #$cdo fldsum tmp1.nc tmp2.nc
 	$cdo -fldsum -mul ${ifile} area.nc tmp1.nc
    elif [ "$oper" = "fldmean" ] ; then
        #$cdo -f nc gridweights ${ifile} weights.nc
        $cdo fldmean ${ifile} tmp1.nc
    else
        cp ${ifile} tmp1.nc
    fi

    # convert units of flux variables to monthly totals and kg to Pg
    if ${flux} ; then
	if ${pg_carbon} ; then
	    $cdo -mulc,86400e-12 -muldpm tmp1.nc tmp2.nc
	    ncatted -O -a units,$cvar,m,c,"Pg C" tmp2.nc
	else
	    $cdo -mulc,86400 -muldpm tmp1.nc tmp2.nc
	fi
    else
   	if ${pg_carbon} ; then
	    ncap2 -O -v -s "$cvar=$cvar*1e-12" tmp1.nc tmp2.nc
	    ncatted -O -a units,$cvar,m,c,"Pg C" tmp2.nc
	else
	    mv tmp1.nc tmp2.nc
	fi
    fi

    # setup time dimension
    $cdo -R settunits,hours -settime,0 -setday,1 tmp2.nc tmp3.nc
    mv tmp3.nc ${out}_${cvar}.nc

    # add co2s which is co2 at near-surface in ppm
    if [ $cvar = "co2" ] ; then
        $cdo sellevel,92500 ${out}_${cvar}.nc tmp1.nc
        ncap2 -O -v -s "co2s=co2*1e6" tmp1.nc ${out}_co2s.nc
	ncatted -O -a units,co2s,m,c,"ppm" ${out}_co2s.nc
	ncatted -O -a long_name,co2s,m,c,"CO2 concentration at 925 hPa" ${out}_co2s.nc
    fi

    # convert co2mass (kg CO2) to cAtmos (Pg C)
    if [ $cvar = "co2mass" ] ; then
        ncap2 -O -v -s "cAtmos=co2mass*2.72727273e-13" ${out}_co2mass.nc ${out}_cAtmos.nc
	ncatted -O -a units,cAtmos,m,c,"Pg C" ${out}_cAtmos.nc
	ncatted -O -a long_name,cAtmos,m,c,"Total Carbon in Atmosphere (TM5)" ${out}_cAtmos.nc
    #elif [ $cvar = "cLand" ] ; then
    #    ncap2 -O -v -s "$cvar=$cvar*1e-12" ${out}_${cvar}.nc tmp1.nc
    #	 ncatted -O -a units,$cvar,m,c,"Pg C" tmp1.nc ${out}_${cvar}.nc
    fi
    
    rm -f tmp?.nc area.nc weights.nc

done


# process yearly vars, obtained from custom output (raw model output, diags, etc.)

# where to save (archive) the results
OUTDIR2=$OUTDIR0/year/Post_$year
mkdir -p $OUTDIR2 || exit -1

# output filename root
out=$OUTDIR2/${expname}_${year}

# for PISCES - special treatment of ocean.carbon
if [ ${ccycle_pisces} == 1 ] ; then
    #$python $PROGDIR/script/ocean_carbon_csv2nc.py ${ECE3_POSTPROC_RUNDIR}/ocean.carbon ${out}_ocean_carbon.nc
    cp ${ECE3_POSTPROC_RUNDIR}/ocean.carbon ${out}_ocean.carbon
fi

# loop over yearly vars
for cvar in ${yearvars[*]}; do

    rm -f tmp?.nc area.nc weights.nc

    # define idir, ifile
    cmor_table=""
    oper=""
    idir=""
    ifile=""
    factor=""
    flux=false
    shiftyear=false
    if [ $cvar = "cLand" ] ; then
        cmor_table="Eyr"
        oper="fldsum"
	pg_carbon=true
	shiftyear=true
    elif [ $cvar = "cFlux" ] ; then
        cmor_table="Eyr"
        oper="fldsum"
	flux=true
	pg_carbon=true
	shiftyear=true
    elif [ $cvar = "co2mass" ] ; then
        cmor_table=""
        oper="fldsum"
	idir=${TM5RESULTS}
	ifile=$( cd ${idir} && ls co2mass_AERday_*_${year}0101-${year}1231.nc )
	ifile_area=$( cd ${idir} && ls co2mass_AERday_*_${year}0101-${year}1231.nc )
    else
        echo "undefined var $cvar"
        exit 1
    fi
    if [ "${cmor_table}" != "" ] ; then
	idir=$( echo $CMORRESULTS/*/*/*/*/*/${cmor_table}/${cvar}/*/* )
	ifile=$( cd ${idir} && ls ${cvar}_${cmor_table}_*_${year}*-${year}*.nc )
    fi

    if [ "$ifile" = "" ] ; then
	echo "ccycle_post.sh: cannot find input file for variable $cvar !"
	exit 1
    fi

    # copy file (making subset/fix if required)
    if [ $cvar = "co2mass" ] ; then
	$cdo -seltimestep,1 ${idir}/${ifile} ${ifile}
    #use the first month of Emon/cLand if we don't have Eyr/cLand
    #elif [ $cvar = "cLand" ] ; then
	#$cdo -seltimestep,1 ${idir}/${ifile} ${ifile}
    else
	cp ${idir}/${ifile} .
    fi

    # perform operation
    if [ $oper = "fldsum" ] ; then
	[ $cvar = "co2mass" ] && cp ${idir}/areacella_*.nc area.nc || $cdo -f nc gridarea ${ifile} area.nc
        #$cdo mul ${ifile} area.nc tmp1.nc
        #$cdo fldsum tmp1.nc tmp2.nc
 	$cdo -fldsum -mul ${ifile} area.nc tmp1.nc
    elif [ $oper = "fldmean" ] ; then
        #$cdo -f nc gridweights ${ifile} weights.nc
        $cdo fldmean ${ifile} tmp1.nc
    else
        cp ${ifile} tmp1.nc
    fi

    # convert units of flux variables to yearly totals and kg to Pg
    if ${flux} ; then
	if ${pg_carbon} ; then
	    $cdo -mulc,86400e-12 -muldpy tmp1.nc tmp2.nc
	    ncatted -O -a units,$cvar,m,c,"Pg C" tmp2.nc
	else
	    $cdo -mulc,86400 -muldpy tmp1.nc tmp2.nc
	fi
    else
   	if ${pg_carbon} ; then
	    ncap2 -O -v -s "$cvar=$cvar*1e-12" tmp1.nc tmp2.nc
	    ncatted -O -a units,$cvar,m,c,"Pg C" tmp2.nc
	else
	    mv tmp1.nc tmp2.nc
	fi
    fi

    # setup time dimension
    if $shiftyear ; then
	$cdo -R settunits,hours -setdate,$(( year+1 ))-01-01 tmp2.nc tmp3.nc
    else
	$cdo -R settunits,hours -settime,0 -setday,1 tmp2.nc tmp3.nc
    fi
    mv tmp3.nc ${out}_${cvar}.nc

    # convert co2mass (kg CO2) to cAtmos (Pg C)
    if [ $cvar = "co2mass" ] ; then
        ncap2 -O -v -s "cAtmos=co2mass*2.72727273e-13" ${out}_co2mass.nc ${out}_cAtmos.nc
	ncatted -O -a units,cAtmos,m,c,"Pg C" ${out}_cAtmos.nc
	ncatted -O -a long_name,cAtmos,m,c,"Total Carbon in Atmosphere" ${out}_cAtmos.nc
    #elif [ $cvar = "cLand" ] ; then
    #    ncap2 -O -v -s "$cvar=$cvar*1e-12" ${out}_${cvar}.nc tmp1.nc
    # 	 ncatted -O -a units,$cvar,m,c,"Pg C" tmp1.nc ${out}_${cvar}.nc
    fi

    rm -f tmp?.nc area.nc weights.nc

done


# loop over yearly vars
for cvar in ${yearvars2[*]}; do
    $cdo -seltimestep,1 $OUTDIR/${expname}_${year}_${cvar}.nc $OUTDIR2/${expname}_${year}_${cvar}.nc
done

for cvar in ${yearvars3[*]}; do
    #$cdo yearsum $OUTDIR/${expname}_${year}_${cvar}.nc $OUTDIR2/${expname}_${year}_${cvar}.nc
    #$cdo shifttime,"+1year" -settime,0 -setday,1 -setmon,1 -yearsum $OUTDIR/${expname}_${year}_${cvar}.nc $OUTDIR2/${expname}_${year}_${cvar}.nc
    $cdo -O setdate,$(( year+1 ))-01-01 -yearsum $OUTDIR/${expname}_${year}_${cvar}.nc $OUTDIR2/${expname}_${year}_${cvar}.nc
done


cd -
rm -rf $WRKDIR
