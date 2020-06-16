#!/usr/bin/env bash

#set -eu
set -xuve
export HERE=`pwd`

export PYTHONPATH=${HERE}/scripts/barakuda_modules

usage()
{
    echo
    echo "USAGE: ${0} -R <run name> (options)"
    echo
    echo "   OPTIONS:"
    echo "      -y <YYYY>    => force initial year to YYYY"
    echo "      -f           => forces a clean start for diags"
    echo "                      (restart everything from scratch...)"
    echo "      -e           => create the HTML diagnostics page on local or remote server"
    echo "      -o           => check for previous run files and use them"
    echo "      -h           => print this message"
    echo
    exit
}

RUN=""
YEAR0="" ; iforcey0=0

IPREPHTML=0
IFORCENEW=0

while getopts R:y:t:foeh option ; do
    case $option in
        R) RUN=${OPTARG};;
        y) YEAR0=${OPTARG} ; iforcey0=1 ;;
        f) IFORCENEW=1;;
	o) CONTINUE=1 ;;
        e) IPREPHTML=1;;
        h)  usage;;
        \?) usage ;;
    esac
done

TEMPDIR=$(eval echo $ECE3_POSTPROC_TMPDIR)
mkdir -p $TEMPDIR
export TMPDIR_ROOT=$(mktemp -d $TEMPDIR/ts_${RUN}_XXXXXX)
export POST_DIR=$DATADIR

echo
echo " *** TMPDIR_ROOT = ${TMPDIR_ROOT}"
echo " *** POST_DIR = ${POST_DIR}"
echo " *** DIR_TIME_SERIES = ${DIR_TIME_SERIES}"
echo " *** RHOST = ${RHOST:=}"
echo " *** RUSER = ${RUSER:=}"
echo " *** WWW_DIR_ROOT = ${WWW_DIR_ROOT:=}"
echo " *** PYTHONPATH = ${PYTHONPATH}"
echo

# Root path for temporary directory:
TMPDIR=${TMPDIR_ROOT}

# On what variable should we test files:
cv_test="cLand"

# *** end of conf ***

is_leap()
{
    if [ "$1" = "" ]; then echo "USAGE: lb_is_leap <YEAR>"; exit; fi
    #
    i_mod_400=`expr ${1} % 400`
    i_mod_100=`expr ${1} % 100`
    i_mod_4=`expr ${1} % 4`
    #
    if [ ${i_mod_400} -eq 0 -o ${i_mod_4} -eq 0 -a ! ${i_mod_100} -eq 0 ]; then
        echo "1"
    else
        echo "0"
    fi
}

export RUN=${RUN}

if [ "${RUN}" = "" ]; then
    echo; echo "Specify which runs to be treated with the \"-R\" switch!"; echo
    usage
    exit
fi

RWWWD=${WWW_DIR_ROOT}/time_series/${RUN}

echo " Runs to be treated: ${RUN}"; echo

# where to create diagnostics:
export DIAG_D=${DIR_TIME_SERIES}/ccycle

if [ ${IFORCENEW} -eq 1 ]; then
    echo "Forcing clean restart! => removing ${DIAG_D}"
    rm -rf ${DIAG_D}
    echo
fi

# Need to know first and last year
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ca=`\ls ${DATADIR}/Post_????/*_${cv_test}.nc | head -1` ; ca=`basename ${ca}` ;
export YEAR_INI=`echo ${ca} | sed -e "s/${RUN}_//g" -e "s/_${cv_test}.nc//g"`

ca=`\ls ${DATADIR}/Post_????/*_${cv_test}.nc | tail -1` ; ca=`basename ${ca}` ;
export YEAR_END=`echo ${ca} | sed -e "s/${RUN}_//g" -e "s/_${cv_test}.nc//g"`

# Checking if they at least are 4-digits integers
if [[ ! ${YEAR_INI} =~ ^[0-9]{4}$ ]]
then
    echo "ERROR: it was imposible to guess initial year from your input files"
    echo "       maybe the directory contains non-related files..."
    echo "      => use the -y <YEAR> switch to force the initial year!"; exit
fi
if [[ ! ${YEAR_END} =~ ^[0-9]{4}$ ]]
then
    echo "ERROR: it was imposible to guess the year coresponding to the last saved year!"
    echo "       => check your IFS output directory and file naming..."; exit
fi

# Checking if analysis has been run previously
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FILELIST=(${DIAG_D}/${RUN}*.nc)
BASE_YEAR_INI=

YEAR_I=${YEAR_INI}

if [ -e ${FILELIST[0]}  ] ; then
    echo " Timeseries analysis has been performed and files has been saved..." ; echo
    OLD_SUPA_FILE=$( ls -tr ${DIAG_D}/${RUN}_${YEAR_INI}*_time-series_ccycle.nc | tail -1 )
    OLD_YEAR_END=$(basename $OLD_SUPA_FILE | sed "s|${RUN}_${YEAR_INI}_\(....\).*|\1|")
    
    if [[ ${OLD_YEAR_END} -ne ${YEAR_END} ]] ; then
         BASE_YEAR_INI=${YEAR_INI}
         YEAR_INI=$(( ${OLD_YEAR_END} + 1 ))
         echo " Initial year forced to ${YEAR_INI}"; echo
    else
         echo " Values up to date!" ; echo
         if [[ $IPREPHTML -eq 0 ]] ; then
             exit
         fi
    fi
fi

echo " Initial year guessed from stored files => ${YEAR_INI}"
echo " Last year guessed from stored files => ${YEAR_END}"; echo
if [ ${iforcey0} -eq 1 ]; then
    export YEAR_INI=${YEAR0}
    echo " Initial year forced to ${YEAR_INI}"; echo
fi

SUPA_FILE=${DIAG_D}/${RUN}_${YEAR_INI}_${YEAR_END}_time-series_ccycle.nc
[[ ! -z ${BASE_YEAR_INI} ]] && tmp_year_ini=${BASE_YEAR_INI} || tmp_year_ini=${YEAR_INI}
SUPA_FILE_MON=${DIAG_D}/${RUN}_${tmp_year_ini}_${YEAR_END}_time-series_ccycle_mon.nc
SUPA_FILE_MEAN=${DIAG_D}/${RUN}_${tmp_year_ini}_${YEAR_END}_time-series_ccycle_mean.nc
SUPA_FILE_M1=${DIAG_D}/${RUN}_${tmp_year_ini}_${YEAR_END}_time-series_ccycle_m1.nc
SUPA_FILE_M12=${DIAG_D}/${RUN}_${tmp_year_ini}_${YEAR_END}_time-series_ccycle_m12.nc
SUPA_FILE_FLUX=${DIAG_D}/${RUN}_${tmp_year_ini}_${YEAR_END}_time-series_ccycle_flux.nc
SUPA_FILE_YEAR=${DIAG_D}/${RUN}_${tmp_year_ini}_${YEAR_END}_time-series_ccycle_year.nc
SUPA_FILE_PISCES=${DIAG_D}/${RUN}_${tmp_year_ini}_${YEAR_END}_time-series_ccycle_pisces.nc

SUPA_FILE_TEST=${DIAG_D}/${RUN}_drift_test.nc

export SUPA_FILE

# ~~~~~~~~~~~~~~~~~~~~~~~`

jyear=${YEAR_INI}

# monthly and yearly vars, which we processed in ccycle_post.sh
monvars_state="" #monthly files, state variables
monvars_flux="" #monthly files, flux variables
monvars_flux2="" #diag fluxes
yearvars="" #yearly files

if [ ${ccycle_lpjg} == 1 ] ; then
    monvars_state+=" cLand cVeg cProduct cLitter cSoil cLand1"
    monvars_flux+=" nbp nep fco2nat fco2antt fCLandToOcean npp gpp"
    yearvars+=" cLandYr cFluxYr"
fi
[ ${ccycle_tm5} == 1 ] && monvars_state+=" co2s co2mass cAtmos" && yearvars+=" co2sYr co2massYr cAtmosYr"
[ ${ccycle_tm5} == 1 ] && monvars_flux+=" fco2fos"
[ ${ccycle_pisces} == 1 ] && monvars_flux+=" fgco2"

# sanity check since we now assume that both lpjg and pisces are required
if [ ${ccycle_pisces} != 1 ] || [ ${ccycle_lpjg} != 1 ] ; then echo "ERROR! monitor_ccycle.sh requires both lpjg and pisces activated!" ; exit 1 ; fi

[ ${ccycle_lpjg} == 1 ] && [ ${ccycle_pisces} == 1 ] && yearvars+=" fGeoYr cGeoYr"


# should missing values in the first and last years of the yearly timeseries be extrapolated?
missval_extrapolate=false

fcompletion=${DIAG_D}/last_year_done.info

if [ ${IPREPHTML} -eq 0 ]; then

    echo " Will store all extracted time series into:"
    echo " ${SUPA_FILE}"

    # create output directory if necessary
    mkdir -p ${DIAG_D} || exit

    # Temporary directory:
    rand_strg=`dd if=/dev/urandom count=128 bs=1 2>&1 | md5sum | cut -b-8`
    TMPD=${TMPDIR}/ccycle_time_series.${RUN}.${rand_strg}
    mkdir -p ${TMPD} || exit

    jyear=${YEAR_INI}

    #if [ -f ${fcompletion} ]; then jyear=`cat ${fcompletion}`; jyear=`expr ${jyear} + 1`; fi

    icontinue=1

    rm -f ${SUPA_FILE}

    # Loop along years:
    while [ ${icontinue} -eq 1 ]; do

        echo; echo " **** year = ${jyear}"

        # Testing if the current year has been done
        ftst=${DATADIR}/Post_????/${RUN}_${jyear}_${cv_test}.nc

        if [ ! -f ${ftst} ]; then
            echo "Year ${jyear} is not completed yet:"; echo " => ${ftst} is missing"; echo
            icontinue=0
        fi

        if [ ${icontinue} -eq 1 ]; then
            echo
            echo " Starting diagnostic for ${RUN} for year ${jyear} !"
            echo

            nbday=365
            if [ `is_leap ${jyear}` -eq 1 ]; then
                echo " ${jyear} is leap!!!!"; echo
                nbday=366
            fi

            SUPA_Y=${RUN}_${jyear}_time-series_ccycle.tmp

            cd ${TMPD}/

            jv=0
            for cvar in ${monvars_flux[*]} ${monvars_state[*]}; do

                rm -f tmp.nc tmp2.nc

                echo "cdo -R -t -fldmean ${DATADIR}/Post_????/${RUN}_${jyear}_${cvar}.nc tmp0.nc"
                cdo -R -fldmean ${DATADIR}/Post_????/${RUN}_${jyear}_${cvar}.nc tmp0.nc
                echo
                
                ncwa -3 -O -a lat,lon tmp0.nc -o tmp.nc ; rm tmp0.nc ; # removing degenerate lat and lon dimensions

                # Creating time vector if first year:
                if [ ${jv} -eq 0 ]; then
                    rm -f time_${jyear}.nc
                    ncap2 -3 -h -O -s "time=(time/24.+15.5)/${nbday}" tmp.nc -o tmp0.nc
                    ncap2 -3 -h -O -s "time=time-time(0)+${jyear}+15.5/${nbday}" \
                        -s "time@units=\"years\"" tmp0.nc -o tmp2.nc
		    # remove the 15.5 day offset to be able to compare with ocean data on Jan 1 00:00
#                    ncap2 -3 -h -O -s "time=(time/24.)/${nbday}" tmp.nc -o tmp0.nc
#                    ncap2 -3 -h -O -s "time=time-time(0)+${jyear}" \
#                        -s "time@units=\"years\"" tmp0.nc -o tmp2.nc
                    ncks -3 -h -O -v time tmp2.nc -o time_${jyear}.nc
                    rm -f tmp0.nc tmp2.nc
                fi

                # Creating correct time array:
                ncks -3 -A -h -v time time_${jyear}.nc -o tmp.nc
                ncap2 -3 -h -O -s "time=time+${jyear}" -s "time@units=\"years\"" tmp.nc -o tmp2.nc
                rm -f tmp.nc

                #if [ ! "${cvar}" = "${cvar_nc}" ]; then
                #    echo "ncrename -v ${cvar_nc},${cvar} tmp2.nc"
                #    ncrename -h -v ${cvar_nc},${cvar} tmp2.nc
                #    echo
                #fi

                echo "ncks -3 -A -v ${cvar} tmp2.nc -o ${SUPA_Y}"
                ncks -3 -h -A -v ${cvar} tmp2.nc -o ${SUPA_Y}
                echo

                rm -f tmp2.nc

                jv=`expr ${jv} + 1`

            done

            
            echo " ${SUPA_Y} done..."; echo; echo
            
        fi

        jyear=`expr ${jyear} + 1`

    done  # ${icontinue} -eq 1

    ncrcat -h -O ${RUN}_*_time-series_ccycle.tmp -o ${SUPA_FILE}
    
    ncrcat -O time_*.nc -o supa_time.nc
    echo "ncks -3 -A -h -v time supa_time.nc -o ${SUPA_FILE}"
    ncks -3 -A -h -v time supa_time.nc -o ${SUPA_FILE}

    rm -f ${RUN}_*_time-series_ccycle.tmp time_*.nc supa_time.nc


    echo
    echo " Time series saved into:"
    echo " ${SUPA_FILE}"
    echo

    #Concatenate new and old files... 
    if [[ ! -z ${BASE_YEAR_INI} ]] ; then
         echo " Concatenate old and new netcdf files... " 
         ncrcat -h ${OLD_SUPA_FILE} ${SUPA_FILE} ${DIAG_D}/${RUN}_${BASE_YEAR_INI}_${YEAR_END}_time-series_ccycle.nc
         rm ${OLD_SUPA_FILE} ${SUPA_FILE}
	 # TODO old SUPA_FILE2 and SUPA_FILE3
         #rm ${OLD_SUPA_FILE2} ${OLD_SUPA_FILE3}
         export SUPA_FILE=${DIAG_D}/${RUN}_${BASE_YEAR_INI}_${YEAR_END}_time-series_ccycle.nc
         echo " Variables saved in ${RUN}_${BASE_YEAR_INI}_${YEAR_END}_time-series_ccycle.nc " ; echo
    fi

    # generate ocean_carbon diags from csv file
    if [ ${ccycle_pisces} == 1 ] ; then
	#cp ${DATADIR}/Post_????/${RUN}_${YEAR_END}_ocean_carbon.nc ${SUPA_FILE}
	tmpf=${DATADIR}/../year/Post_${YEAR_END}/${RUN}_${YEAR_END}_ocean.carbon
	#${PYTHON} ${HERE}/scripts/ocean_carbon_csv2nc.py ${tmpf} ${tmpf}.nc ${DIAG_D}/diags_pisces_${RUN}.csv
	cdo seldate,${tmp_year_ini}-01-01,${YEAR_END}-12-31 ${tmpf}.nc ${SUPA_FILE_PISCES}
	cp ${tmpf}.csv ${DIAG_D}/diags_pisces_${RUN}.csv

	# TMP ET test the drift plot with data from a249
	#if [ -f "/gpfs/scratch/bsc32/bsc32051/pub/a249/drift_a249.csv" ] ; then
	if false ; then
	    cp /gpfs/scratch/bsc32/bsc32051/pub/a249/drift_a249.csv ${DATADIR}/../year/drift_test.csv
	    ${PYTHON} ${HERE}/scripts/csv2nc.py ${DATADIR}/../year/drift_test.csv ${SUPA_FILE_TEST}
	fi
    fi
    
 
    # generate yearly files from monthly files (m1, m12, sum)
    rm -f tmp*.nc
    cdo -O settunits,seconds -settaxis,${tmp_year_ini}-01-15,00:00:00,month -settunits,month ${SUPA_FILE} ${SUPA_FILE_MON}

    for cvar in ${monvars_state}; do
	$cdo -selmon,1 -selvar,${cvar} ${SUPA_FILE_MON} tmp_m1_${cvar}.nc
	$cdo -selmon,12 -selvar,${cvar} ${SUPA_FILE_MON} tmp_m12_${cvar}.nc
	#$cdo date,${YEAR_INI}-01-01 -yearmean -selvar,${cvar} ${SUPA_FILE_MON} tmp_mean_${cvar}.nc
	$cdo -setmon,1 -setday,1 -yearmean -selvar,${cvar} ${SUPA_FILE_MON} tmp_mean_${cvar}.nc
    done
    for cvar in ${monvars_flux}; do
	#$cdo -setdate,${YEAR_INI}-01-01 -yearsum -selvar,${cvar} ${SUPA_FILE_MON} tmp_flux_${cvar}.nc
	$cdo -setmon,1 -setday,1 -yearsum -selvar,${cvar} ${SUPA_FILE_MON} tmp_flux_${cvar}.nc
	#$cdo -yearsum -selvar,${cvar} ${SUPA_FILE_MON} tmp_flux_${cvar}.nc
    done
    cdo -O -merge tmp_m1_*.nc ${SUPA_FILE_M1}
    cdo -O -merge tmp_m12_*.nc ${SUPA_FILE_M12}
    cdo -O -merge tmp_mean_*.nc ${SUPA_FILE_MEAN}
    #$cdo -O setdate,$(( year+1 ))-01-01 -yearsum $OUTDIR/${expname}_${year}_${cvar}.nc $OUTDIR2/${expname}_${year}_${cvar}.nc
    cdo -O -merge tmp_flux_*.nc ${SUPA_FILE_FLUX}
    
    rm -f tmp*.nc

    # generate yearly diagnostics
    # first get complete yearly timeseries for each var from the hiresclim yearly data
    rm -f tmp_*.nc

    for cvar in ${yearvars}; do
        cdo -O mergetime ${DATADIR}/../year/Post_????/${RUN}_????_${cvar}.nc tmp_${cvar}.nc
	if [ ${YEAR_I} != ${YEAR_END} ] ; then
	    cdo splityear tmp_${cvar}.nc tmp_${cvar}_
	    rm -f tmp_${cvar}.nc
	    if false ; then # deactivated extrapolate code...
	    if [ ! -f tmp_${cvar}_${YEAR_I}.nc ] ; then
		if ${missval_extrapolate} ; then
		    cdo -setyear,${YEAR_I} tmp_${cvar}_$(( YEAR_I+1 )).nc tmp_${cvar}_${YEAR_I}.nc
		else
		    #cdo -setrtomiss,-inf,inf -setyear,${YEAR_I} tmp_${cvar}_${YEAR_END}.nc tmp_${cvar}_${YEAR_I}.nc
		    cdo -setrtoc,-inf,inf,nan -setyear,${YEAR_I} tmp_${cvar}_$(( YEAR_I+1 )).nc tmp_${cvar}_${YEAR_I}.nc
		fi
	    elif [ ! -f tmp_${cvar}_$(( YEAR_END+1 )).nc ] ; then
		if ${missval_extrapolate} ; then
		    cdo -setyear,$(( YEAR_END+1 )) tmp_${cvar}_${YEAR_END}.nc tmp_${cvar}_$(( YEAR_END+1 )).nc
		else
		    # TODO set to miss, fix bug that plotting routine does not recognize missval
		    # and this netcdf error
		    #+ cdo -O mergetime tmp_co2mass_1850.nc tmp_co2mass_1851.nc tmp_co2mass_1852.nc tmp_co2mass.nc
		    #Error (cdf_put_att_double) : NetCDF: Attempt to define fill value when data already exists.
		    #cdo -setrtomiss,-inf,inf -setyear,$(( YEAR_END+1 )) tmp_${cvar}_${YEAR_I}.nc tmp_${cvar}_$(( YEAR_END+1 )).nc
		    cdo -setrtoc,-inf,inf,nan -setyear,$(( YEAR_END+1 )) tmp_${cvar}_${YEAR_END}.nc tmp_${cvar}_$(( YEAR_END+1 )).nc
		fi
	    fi
	    fi
            cdo -O mergetime  tmp_${cvar}_????.nc tmp_${cvar}.nc
	    rm -f tmp_${cvar}_????.nc
	fi
    done


    # get some variables from special pisces diags
    #if [ ${ccycle_pisces} == 1 ] ; then
	for v in cOceanYr fgco2_p4z rivsed_p4z corr_p4z ; do
	    cdo selvar,${v} ${SUPA_FILE_PISCES} tmp_${v}.nc
	done
    #fi
    # get flux variables
    for cvar in fco2nat fco2antt fgco2 fCLandToOcean; do
	cdo selvar,${cvar} ${SUPA_FILE_FLUX} tmp_${cvar}.nc
    done
    [ ${ccycle_tm5} == 1 ] && cdo selvar,fco2fos ${SUPA_FILE_FLUX} tmp_fco2fos.nc

    # compute model-specific fluxes (relative to atmosphere)
    cdo -O -chvar,fco2antt,fLandYr -add tmp_fco2antt.nc tmp_fco2nat.nc tmp_fLandYr.nc
    ncatted -O -a long_name,fLandYr,m,c,"Total C flux from Land" tmp_fLandYr.nc
    cdo -O -chvar,fgco2,fOceanYr -mulc,-1 tmp_fgco2.nc tmp_fOceanYr.nc
    ncatted -O -a long_name,fOceanYr,m,c,"Total C flux from Ocean" tmp_fOceanYr.nc

    # create the cTotal variable by adding cAtmos cLand cOcean and fGeo(t-1)
    if [ ${ccycle_tm5} == 1 ] ; then
	cdo -O -chvar,cOceanYr,cTotalYr -add tmp_cOceanYr.nc -add tmp_cLandYr.nc -add tmp_cAtmosYr.nc tmp_cGeoYr.nc tmp_cTotalYr.nc
	#cdo -O -chvar,cOceanYr,cTotalYr -add tmp_cOceanYr.nc -add tmp_cLandYr.nc tmp_cAtmosYr.nc tmp_cTotalYr.nc
	ncatted -O -a long_name,cTotalYr,m,c,"Total Carbon in Atmosphere, Land, Ocean and Geo" tmp_cTotalYr.nc
    else
	cdo -O -chvar,cOceanYr,cTotalYr -add tmp_cOceanYr.nc -add tmp_cLandYr.nc tmp_cGeoYr.nc tmp_cTotalYr.nc
	#cdo -O -chvar,cOceanYr,cTotalYr -add tmp_cOceanYr.nc tmp_cLandYr.nc tmp_cTotalYr.nc
	ncatted -O -a long_name,cTotalYr,m,c,"Total Carbon in Land, Ocean and Geo" tmp_cTotalYr.nc
    fi


    # merge all variables in one file
    cdo merge tmp_*.nc ${SUPA_FILE_YEAR}
    rm -f tmp_*.nc

    #cleanup old files
    if [[ ! -z ${BASE_YEAR_INI} ]] ; then
	rm -f ${DIAG_D}/${RUN}_${tmp_year_ini}_$(( YEAR_END -1 ))_time-series_ccycle_*.nc
    fi

    # create diagnostics csv files
    #for f in ${SUPA_FILE_MEAN} ${SUPA_FILE_FLUX} ${SUPA_FILE_YEAR} ; do
    #for f in ${SUPA_FILE_MON} ${SUPA_FILE_MEAN} ${SUPA_FILE_FLUX} ${SUPA_FILE_YEAR} ; do
	#${PYTHON} ${HERE}/scripts/nc2csv.py $f "${f%.*}".csv
	#cp "${f%.*}".csv ${DIAG_D}/${RUN}
    #done
    ${PYTHON} ${HERE}/scripts/nc2csv.py ${SUPA_FILE_MON} ${DIAG_D}/diags_mon_${RUN}.csv
    ${PYTHON} ${HERE}/scripts/nc2csv.py ${SUPA_FILE_MEAN} ${DIAG_D}/diags_mean_${RUN}.csv
    ${PYTHON} ${HERE}/scripts/nc2csv.py ${SUPA_FILE_FLUX} ${DIAG_D}/diags_flux_${RUN}.csv
    ${PYTHON} ${HERE}/scripts/nc2csv.py ${SUPA_FILE_YEAR} ${DIAG_D}/diags_year_${RUN}.csv

    cd ..
    rm -rf ${TMPD}


fi # [ ${IPREPHTML} -eq 0 ]


if [ ${IPREPHTML} -eq 1 ]; then


    if [ ! -f ${SUPA_FILE} ]; then
        echo
        echo " PROBLEM: we cannot find ${SUPA_FILE} !!!"
        exit
    fi

    cd ${DIAG_D}/

    # do the plots

    export CCYCLE_TM5=${ccycle_tm5}
    export CCYCLE_EMISS_FIXYEAR=${ccycle_emiss_fixyear}


    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series.py

    export SUPA_FILE=${SUPA_FILE_MEAN}
    export OUTFILE_SUFFIX="mean"
    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series3.py
    
    export SUPA_FILE=${SUPA_FILE_M1}
    export OUTFILE_SUFFIX="m1"
    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series3.py
    
    export SUPA_FILE=${SUPA_FILE_M12}
    export OUTFILE_SUFFIX="m12"
    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series3.py

    export SUPA_FILE=${SUPA_FILE_FLUX}
    export OUTFILE_SUFFIX="flux"
    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series3.py
    
    export SUPA_FILE=${SUPA_FILE_PISCES}
    export PLOT_DRIFT=false
    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series2.py


    export SUPA_FILE=${SUPA_FILE_YEAR}
    export PLOT_DRIFT=true
    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series2.py
    
    # TMP ET test the drift plot with data from a249
    if [ -f ${SUPA_FILE_TEST} ] ; then
	export SUPA_FILE=${SUPA_FILE_TEST}
	RUN_orig=${RUN}
	export RUN=test
	${PYTHON} ${HERE}/scripts/plot_ccycle_time_series2.py
	export RUN=${RUN_orig}
    fi

    # Configuring HTML display file:
    [ ${ccycle_lpjg} == 1 ] && display_lpjg="" || display_lpjg=" ; display:none"
    [ ${ccycle_pisces} == 1 ] && display_pisces="" || display_pisces=" ; display:none"
    [ ${ccycle_tm5} == 1 ] && display_tm5="" || display_tm5=" ; display:none"
    sed -e "s/{TITLE}/Carbon cycle diagnostics for EC-Earth coupled experiment/g" \
        -e "s/{RUN}/${RUN}/g" -e "s/{DATE}/`date`/g" -e "s/{HOST}/`hostname`/g" \
        -e "s/{DISPLAY_TM5}/${display_tm5}/g" \
        ${HERE}/scripts/index_ccycle_skel.html > index.html
    
    
    if [ ! "${RHOST}" = "" ]; then
        echo "Preparing to export to remote host!"; echo
        cd ../
        tar cvf ccycle.tar ccycle
        ssh ${RUSER}@${RHOST} "mkdir -p ${RWWWD}"
        echo "scp ccycle.tar ${RUSER}@${RHOST}:${RWWWD}/"
        scp ccycle.tar ${RUSER}@${RHOST}:${RWWWD}/
        ssh ${RUSER}@${RHOST} "cd ${RWWWD}/; rm -rf ccycle; tar xf ccycle.tar 2>/dev/null; rm ccycle.tar"
        echo; echo
        echo "Diagnostic page installed on remote host ${RHOST} in ${RWWWD}/ccycle!"
        echo "( Also browsable on local host in ${DIAG_D}/ )"
        rm -rf ccycle.tar
    else
        echo "Diagnostic page installed in ${DIAG_D}/"
        echo " => view this directory with a web browser (index.html)..."
    fi

    echo; echo

fi # [ ${IPREPHTML} -eq 1 ]


rm -rf ${TMPDIR}
rm -rf ${TEMPDIR}
