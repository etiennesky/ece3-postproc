#!/bin/bash

# script adapted from ccycle_post.sh developped in the ece3-postproc package

set -xuve

#ECE3_POSTPROC_DATADIR=/gpfs/scratch/cns60/cns60490/a2vq/32850101/fc0/inidata
ECE3_POSTPROC_DATADIR=/gpfs/projects/bsc32/models/ecearth/v3.3.3/inidata/

tmpdir=$SCRATCH/tmp/fco2fos/tmp
idir=$SCRATCH/tmp/fco2fos/result

mkdir -p $tmpdir
mkdir -p $idir

module purge
module load intel/2017.4 impi/2017.4 mkl/2017.4
module load gsl grib netcdf hdf5 CDO/1.8.2 udunits nco python/2.7.13
module list

cdo=cdo

cvar=fco2fos

cd $tmpdir

for year in `seq 1993 2014` ; do

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
	    # cdo mulc,0.272727273 # needed to convert from Pg-co2 to Pg-C (was done afterwards)
	    ncatted -O -a units,$cvar,m,c,"Pg C" tmp3.nc
	    ncatted -O -a "standard_name",$cvar,a,c,"tendency_of_atmosphere_mass_content_of_carbon_dioxide_expressed_as_carbon_due_to_emission_from_fossil_fuel_combustion" tmp3.nc
	    ncatted -O -a "long_name",$cvar,m,c,"Carbon Mass Flux into Atmosphere Due to Fossil Fuel Emissions of CO2" tmp3.nc
	    mv tmp3.nc fco2fos_${year}.nc
	    rm -f tmp*.nc

	    mv -f fco2fos_*.nc ${idir}
	    #cdo mergetime ${idir}/fco2fos_*.nc ${idir}/fco2fos.nc


done
