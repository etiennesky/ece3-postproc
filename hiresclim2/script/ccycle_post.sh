#!/bin/bash
set -xuve

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
if [ ${ccycle_lpjg} == 1 ] ; then
    monvars+=" cLand cVeg cProduct cLitter cSoil cLand1 nbp nep fco2nat fco2antt fCLandToOcean npp gpp"
    yearvars+=" cLandYr cFluxYr"
fi
[ ${ccycle_tm5} == 1 ] && monvars+=" co2 co2mass" && yearvars+=" co2Yr co2massYr"
[ ${ccycle_tm5} == 1 ] && monvars+=" fco2fos"
[ ${ccycle_pisces} == 1 ] && monvars+=" fgco2"

[ ${ccycle_lpjg} == 1 ] && [ ${ccycle_pisces} == 1 ] && yearvars+=" cGeoYr"


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
    # state vars
    if [ $cvar = "cLand" ] ; then
        cmor_table="Emon"
        oper="fldsum"
        pg_carbon=true
    elif [ $cvar = "cVeg" ] ; then
        cmor_table="Lmon"
        oper="fldsum"
        pg_carbon=true
    elif [ $cvar = "cProduct" ] ; then
        cmor_table="Lmon"
        oper="fldsum"
        pg_carbon=true
    elif [ $cvar = "cLitter" ] ; then
        cmor_table="Lmon"
        oper="fldsum"
        pg_carbon=true
    elif [ $cvar = "cSoil" ] ; then
        cmor_table="Emon"
        oper="fldsum"
        pg_carbon=true
    elif [ $cvar = "cLand1" ] ; then
        cmor_table="Emon"
        oper="fldsum"
        pg_carbon=true
    # flux vars
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
    elif [ $cvar = "npp" ] ; then
        cmor_table="Lmon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "gpp" ] ; then
        cmor_table="Lmon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "fco2nat" ] ; then
        #cmor_table="Amon"
	#this requires new cmorization with fco2nat in Amon (lpjg+pisces) and Lmon (lpjg)!
        cmor_table="Lmon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "fco2antt" ] ; then
        cmor_table="Amon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "fCLandToOcean" ] ; then
        cmor_table="Emon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    elif [ $cvar = "fgco2" ] ; then
        cmor_table="Omon"
        oper="fldsum"
	flux=true
	pg_carbon=true
    # co2 vars
    elif [ $cvar = "co2" ] ; then
        cmor_table="Amon"
        oper="fldmean"
    elif [ $cvar = "co2mass" ] ; then
        cmor_table="Amon"
        oper=""
    elif [ $cvar = "fco2fos" ] && [ ${ccycle_emiss_fixyear} != 0 ]; then
	ifile=fco2fos.nc
    elif [ $cvar = "fco2fos" ] && [ ${ccycle_emiss_fixyear} == 0 ]; then
        cmor_table=""
        oper=""
	flux=false
	pg_carbon=false

        if [ $year -ge 1750 ] && [ $year -lt 1800 ] ; then
          time_str='175001-179912'
        elif [ $year -ge 1800 ] && [ $year -lt 1850 ] ; then
          time_str='180001-184912'
        elif [ $year -ge 1850 ] && [ $year -lt 1851 ] ; then
          time_str='185001-185012'
        elif [ $year -ge 1851 ] && [ $year -lt 1900 ] ; then
          time_str='185101-189912'
        elif [ $year -ge 1900 ] && [ $year -lt 1950 ] ; then
          time_str='190001-194912'
        elif [ $year -ge 1950 ] && [ $year -lt 2000 ] ; then
          time_str='195001-199912'
        elif [ $year -ge 2000 ] && [ $year -lt 2015 ] ; then
          time_str='200001-201412'
        else
	  time_str=''
	    echo "fco2fos cannot be found for year $year"
	    exit 1
        fi
	idir=${OUTDIR0}/mon

	# use pre-computed fco2fos timeseries (using compute_fco2fos.sh script) if it is found
	# once done the first time copy it outside the experiment folder since it will never change
	if [ -f ${ECE3_POSTPROC_DATADIR}/tm5/CMIP6/fco2fos.nc ] ; then
	    ifile=fco2fos.nc
	    cp ${ECE3_POSTPROC_DATADIR}/tm5/CMIP6/${ifile} ${idir}
	elif [ -f ${ECE3_POSTPROC_DATADIR}/tm5/CMIP6/fco2fos_${year}.nc ] ; then
	    ifile=fco2fos_${year}.nc
	    cp ${ECE3_POSTPROC_DATADIR}/tm5/CMIP6/${ifile} ${idir}
	fi
	if [ ! -f ${idir}/${ifile} ] ; then
	    rm -f fco2fos*.nc

	    d="${ECE3_POSTPROC_DATADIR}/tm5/CMIP6"
	    ifiles="CO2-em-anthro_input4MIPs_emissions_CMIP_CEDS-2017-05-18_gn_${time_str}.nc CO2-em-AIR-anthro_input4MIPs_emissions_CMIP_CEDS-2017-08-30_gn_${time_str}.nc"
	    rm -f tmp_*.nc
	    for f in $ifiles ; do
		#time $cdo -v -O -f nc4c -z zip_2 vertsum -selyear,${year} ${d}/${f} tmp_${f}
		$cdo -f nc4c -z zip_2 -selyear,${year} ${d}/${f} tmp_${f}
		$cdo vertsum tmp_${f} tmp1.nc
		mv tmp1.nc tmp_${f}
	    done
		
	    # this only works because we have 2 ifiles
	    $cdo -f nc chvar,CO2_em_AIR_anthro,fco2fos -add tmp_*.nc tmp1.nc 
	    $cdo gridarea tmp1.nc area.nc
	    $cdo fldsum -mul tmp1.nc area.nc tmp2.nc
	    $cdo -mulc,86400e-12 -muldpm tmp2.nc tmp3.nc
	    # cdo mulc,0.272727273 # needed to convert from Pg-co2 to Pg-C (done afterwards)
	    ncatted -O -a units,$cvar,m,c,"Pg C" tmp3.nc
	    ncatted -O -a "standard_name",$cvar,a,c,"tendency_of_atmosphere_mass_content_of_carbon_dioxide_expressed_as_carbon_due_to_emission_from_fossil_fuel_combustion" tmp3.nc
	    ncatted -O -a "long_name",$cvar,m,c,"Carbon Mass Flux into Atmosphere Due to Fossil Fuel Emissions of CO2" tmp3.nc
	    mv tmp3.nc fco2fos_${year}.nc
	    rm -f tmp*.nc

	    mv -f fco2fos_*.nc ${idir}
	    #cdo mergetime ${idir}/fco2fos_*.nc ${idir}/fco2fos.nc
	    ifile=fco2fos_${year}.nc
	fi
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

    # copy file (foing subset/fix/operation if required)
    if [ $cvar = "co2" ] ; then
	$cdo setctomiss,nan ${idir}/${ifile} ${ifile}
    elif [ $cvar = "fgco2" ] ; then
	# TODO put these somewhere else
	mask=/gpfs/projects/bsc32/models/ecearth/v3.3.3_c-cycle/inidata/nemo/initial/ORCA1L75/nemo-mask-ece.nc
	# cdo griddes selvar,tos ../18500101/fc0/runtime/output/nemo/001/a2vq_1m_18500101_18501231_opa_grid_T_2D.nc > grid-nemo-raw.txt
	# remove area section in grid-nemo-raw.txt
	grid=/gpfs/projects/bsc32/models/ecearth/v3.3.3_c-cycle/inidata/nemo/initial/ORCA1L75/grid-nemo-raw.txt
	rm -f tmp?.nc
	$cdo -f nc setgrid,${grid} -selvar,${cvar} ${idir}/${ifile} tmp1.nc
	ncks -v ${cvar} tmp1.nc tmp2.nc
	$cdo -L -selindexbox,2,361,2,292 -mul tmp2.nc ${mask} ${ifile}
	rm -f tmp?.nc
    elif [ $cvar = "fco2fos" ] && [ ${ccycle_emiss_fixyear} != 0 ]; then
	# ugly hack to get 0-filled fco2fos - we could use pre-computed fco2fos and replace with 0
	vars=( $monvars )
	v1=${vars[0]}
	ifile=fco2fos.nc
	cdo -O -chvar,${v1},${cvar} -mulc,0 ${out}_${v1}.nc ${ifile}
	ncatted -O -a units,$cvar,m,c,"Pg C" ${ifile}
	ncatted -O -a "standard_name",$cvar,a,c,"tendency_of_atmosphere_mass_content_of_carbon_dioxide_expressed_as_carbon_due_to_emission_from_fossil_fuel_combustion" ${ifile}
	ncatted -O -a "long_name",$cvar,m,c,"Carbon Mass Flux into Atmosphere Due to Fossil Fuel Emissions of CO2" ${ifile}
	ncatted -O -a "original_name",$cvar,m,c,"fco2fos" ${ifile}
    elif [ $cvar = "fco2fos" ] && [ ${ccycle_emiss_fixyear} == 0 ]; then
	$cdo selyear,$year ${idir}/${ifile}  ${ifile}
    else
	#cp ${idir}/${ifile} .
	ln -sf ${idir}/${ifile} .
    fi

    # perform operation
    if [ "$oper" = "fldsum" ] ; then
	$cdo -f nc gridarea ${ifile} area.nc
        #$cdo mul area.nc ${ifile} tmp2.nc
        #$cdo fldsum tmp2.nc tmp1.nc     
 	$cdo -f nc -fldsum -mul ${ifile} area.nc tmp1.nc
    elif [ "$oper" = "fldmean" ] ; then
        #$cdo -f nc gridweights ${ifile} weights.nc
        $cdo -f nc fldmean ${ifile} tmp1.nc
    else
        #cp ${ifile} tmp1.nc
        #ln -sf ${ifile} tmp1.nc
        cdo -f nc copy ${ifile} tmp1.nc
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
	tmpvar=co2s
        $cdo sellevel,92500 ${out}_${cvar}.nc tmp1.nc
        ncap2 -O -v -s "${tmpvar}=co2*1e6" tmp1.nc ${out}_${tmpvar}.nc
	ncatted -O -a units,${tmpvar},m,c,"ppm" ${out}_${tmpvar}.nc
	ncatted -O -a long_name,${tmpvar},m,c,"CO2 concentration at 925 hPa" ${out}_${tmpvar}.nc
    fi

    # convert co2mass (kg CO2) to cAtmos (Pg C)
    if [ $cvar = "co2mass" ] ; then
	tmpvar=cAtmos
        ncap2 -O -v -s "${tmpvar}=co2mass*2.72727273e-13" ${out}_co2mass.nc ${out}_${tmpvar}.nc
	ncatted -O -a units,${tmpvar},m,c,"Pg C" ${out}_${tmpvar}.nc
	ncatted -O -a long_name,${tmpvar},m,c,"Total Carbon in Atmosphere (TM5)" ${out}_${tmpvar}.nc
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
    #$python $PROGDIR/script/ocean_carbon_csv2nc.py ${ECE3_POSTPROC_RUNDIR}/ocean.carbon ${out}_ocean.carbon.nc
    cp ${ECE3_POSTPROC_RUNDIR}/ocean.carbon ${out}_ocean.carbon
    $python $PROGDIR/script/ocean_carbon_csv2nc.py ${out}_ocean.carbon ${out}_ocean.carbon.nc ${out}_ocean.carbon.csv
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
    pg_carbon=false
    shiftyear=false
    cmorvar=${cvar}
    if [ $cvar = "cLandYr" ] ; then
        cmor_table="Eyr"
        oper="fldsum"
	pg_carbon=true
	#shiftyear=true
    elif [ $cvar = "cFluxYr" ] ; then
        cmor_table="Eyr"
        oper="fldsum"
	#flux=true
	pg_carbon=true
	#shiftyear=true
    elif [ $cvar = "co2Yr" ] ; then
        cmor_table="Amon"
        oper="fldmean"
	cmorvar="co2"
    elif [ $cvar = "co2massYr" ] ; then
        cmor_table="day"
        oper=""
	cmorvar="co2mass"
    elif [ $cvar = "cGeoYr" ] ; then
	# cGeoYr is a special variable to track carbon leaving/entering the geological pool
	# via fCLandToOcean fgco2 fco2fos 
	if [ $year = $yref ] ; then
	    vars=( $yearvars )
	    v1=${vars[0]}
	    $cdo -setdate,${year}-07-01 -setrtoc,-inf,inf,0 -chname,${v1},${cvar} ${out}_${v1}.nc ${out}_${cvar}.nc
	    ncatted -O -a units,${cvar},m,c,"Pg C" ${out}_${cvar}.nc
	    ncatted -O -a long_name,${cvar},m,c,"Total Carbon in Geo pool" ${out}_${cvar}.nc
	    ncatted -O -a original_name,${cvar},d,c,"" ${out}_${cvar}.nc
	    ncatted -O -a standard_name,${cvar},d,c,"" ${out}_${cvar}.nc
	else
	    y1=$(( year -1 ))
	    out1=$OUTDIR0/year/Post_${y1}/${expname}_${y1}
	    outm1=$OUTDIR0/mon/Post_${y1}/${expname}_${y1}
	    $cdo -O -selvar,rivsed_p4z -selyear,${y1} ${out1}_ocean.carbon.nc tmp_rivsed_p4z.nc
	    $cdo -O -yearsum ${outm1}_fCLandToOcean.nc tmp_fCLandToOcean.nc
	    if [ ${ccycle_tm5} == 1 ] ; then
		$cdo -O -yearsum ${outm1}_fco2fos.nc tmp_fco2fos.nc
		#$cdo -setdate,${year}-07-01 -chvar,fCLandToOcean,${cvar} -add tmp_fCLandToOcean.nc -add -mulc,-1 tmp_fco2fos.nc -mulc,-1 -add tmp_rivsed_p4z.nc ${out1}_${cvar}.nc ${out}_${cvar}.nc
		cdo_expr="cGeoYr=cGeoYr+fCLandToOcean-fco2fos-rivsed_p4z"
	    else
		#$cdo -setdate,${year}-07-01 -chvar,fCLandToOcean,${cvar} -add tmp_fCLandToOcean.nc -mulc,-1 -add tmp_rivsed_p4z.nc ${out1}_${cvar}.nc ${out}_${cvar}.nc
		cdo_expr="cGeoYr=cGeoYr+fCLandToOcean-rivsed_p4z"
	    fi
	    $cdo merge tmp_*.nc ${out1}_${cvar}.nc tmp_merged.nc
	    $cdo -setdate,${year}-07-01 -expr,${cdo_expr} tmp_merged.nc ${out}_${cvar}.nc

	    rm tmp_*.nc
	fi

	continue
    else
        echo "undefined var $cvar"
        exit 1
    fi
    if [ "${cmor_table}" != "" ] ; then
	idir=$( echo $CMORRESULTS/*/*/*/*/*/${cmor_table}/${cmorvar}/*/* )
	ifile=$( cd ${idir} && ls ${cmorvar}_${cmor_table}_*_${year}*-${year}*.nc )
    fi

    if [ "$ifile" = "" ] ; then
	echo "ccycle_post.sh: cannot find input file for variable $cvar !"
	exit 1
    fi

    # copy file (making subset/fix if required)
    if [ $cvar = "co2Yr" ] ; then
	$cdo -f nc -chname,co2,co2Yr -seltimestep,1 ${idir}/${ifile} ${ifile}
    elif [ $cvar = "co2massYr" ] ; then
	$cdo -f nc -chname,co2mass,co2massYr -seltimestep,1 ${idir}/${ifile} ${ifile}
    #use the first month of Emon/cLand if we don't have Eyr/cLand
    #elif [ $cvar = "cLand" ] ; then
	#$cdo -seltimestep,1 ${idir}/${ifile} ${ifile}
    else
	#cp ${idir}/${ifile} .
	ln -sf ${idir}/${ifile} .
    fi

    # perform operation
    if [ "$oper" = "fldsum" ] ; then
	if [ $cvar = "co2massYr" ] || [ $cvar = "co2Yr" ] ; then
	    cp ${idir}/areacella_*.nc area.nc 
	else
	    $cdo -f nc gridarea ${ifile} area.nc
	fi
        #$cdo mul ${ifile} area.nc tmp2.nc
        #$cdo fldsum tmp2.nc tmp1.nc
 	$cdo -f nc -fldsum -mul ${ifile} area.nc tmp1.nc
    elif [ "$oper" = "fldmean" ] ; then
        #$cdo -f nc gridweights ${ifile} weights.nc
        $cdo -f nc fldmean ${ifile} tmp1.nc
    else
        #cp ${ifile} tmp1.nc
        #ln -sf ${ifile} tmp1.nc
        cdo -f nc copy ${ifile} tmp1.nc
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

    # add co2s which is co2 at near-surface in ppm
    if [ $cvar = "co2Yr" ] ; then
	tmpvar=co2sYr
        $cdo sellevel,92500 ${out}_${cvar}.nc tmp1.nc
        ncap2 -O -v -s "${tmpvar}=co2Yr*1e6" tmp1.nc ${out}_${tmpvar}.nc
	ncatted -O -a units,${tmpvar},m,c,"ppm" ${out}_${tmpvar}.nc
	ncatted -O -a long_name,${tmpvar},m,c,"CO2 concentration at near-surface" ${out}_${tmpvar}.nc
    fi

    # convert co2mass (kg CO2) to cAtmos (Pg C)
    if [ $cvar = "co2massYr" ] ; then
	tmpvar=cAtmosYr
        ncap2 -O -v -s "${tmpvar}=co2massYr*2.72727273e-13" ${out}_co2massYr.nc ${out}_${tmpvar}.nc
	ncatted -O -a units,${tmpvar},m,c,"Pg C" ${out}_${tmpvar}.nc
	ncatted -O -a long_name,${tmpvar},m,c,"Total Carbon in Atmosphere" ${out}_${tmpvar}.nc
    #elif [ $cvar = "cLand" ] ; then
    #    ncap2 -O -v -s "$cvar=$cvar*1e-12" ${out}_${cvar}.nc tmp1.nc
    # 	 ncatted -O -a units,$cvar,m,c,"Pg C" tmp1.nc ${out}_${cvar}.nc
    fi

    rm -f tmp?.nc area.nc weights.nc

done


cd -
rm -rf $WRKDIR
