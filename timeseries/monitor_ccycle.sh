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
    OLD_SUPA_FILE2=$( ls -tr ${DIAG_D}/${RUN}_${YEAR_INI}*_time-series_ccycle2.nc | tail -1 )
    OLD_SUPA_FILE3=$( ls -tr ${DIAG_D}/${RUN}_${YEAR_INI}*_time-series_ccycle3.nc | tail -1 )
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
[[ ! -z ${BASE_YEAR_INI} ]] && SUPA_FILE2=${DIAG_D}/${RUN}_${BASE_YEAR_INI}_${YEAR_END}_time-series_ccycle2.nc || SUPA_FILE2=${DIAG_D}/${RUN}_${YEAR_INI}_${YEAR_END}_time-series_ccycle2.nc
[[ ! -z ${BASE_YEAR_INI} ]] && SUPA_FILE3=${DIAG_D}/${RUN}_${BASE_YEAR_INI}_${YEAR_END}_time-series_ccycle3.nc || SUPA_FILE3=${DIAG_D}/${RUN}_${YEAR_INI}_${YEAR_END}_time-series_ccycle3.nc

export SUPA_FILE SUPA_FILE2 SUPA_FILE3

# ~~~~~~~~~~~~~~~~~~~~~~~`

jyear=${YEAR_INI}

monvars="" #monthly files
yearvars="" #yearly files

if [ ${ccycle_lpjg} == 1 ] ; then
    monvars+=" cLand nbp nep fco2nat fco2antt"
    yearvars+=" cLand nbp nep fco2nat fco2antt"
fi
[ ${ccycle_tm5} == 1 ] && monvars+=" co2s co2mass cAtmos" && yearvars+=" co2s co2mass cAtmos"
[ ${ccycle_pisces} == 1 ] && monvars+=" fgco2" && yearvars+=" fgco2"

# should missing values in the first and last years of the yearly timeseries be extrapolated?
missval_extrapolate=true

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
            for cvar in ${monvars[*]}; do

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

    # generate ocean_carbon diags from csv file
    if [ ${ccycle_pisces} == 1 ] ; then
	#cp ${DATADIR}/Post_????/${RUN}_${YEAR_END}_ocean_carbon.nc ${SUPA_FILE}
	tmpf=${DATADIR}/../year/Post_${YEAR_END}/${RUN}_${YEAR_END}_ocean.carbon
	${PYTHON} ${HERE}/scripts/ocean_carbon_csv2nc.py ${tmpf} ${tmpf}.nc
	cp ${tmpf}.nc ${SUPA_FILE3}
    fi

    # generate yearly diagnostics
    # first get complete yearly timeseries for each var from the hiresclim yearly data
    rm -f tmp_*.nc
    for cvar in ${yearvars[*]}; do
        cdo -O mergetime ${DATADIR}/../year/Post_????/${RUN}_????_${cvar}.nc tmp_${cvar}.nc
	if [ ${YEAR_I} != ${YEAR_END} ] ; then
	    cdo splityear tmp_${cvar}.nc tmp_${cvar}_
	    rm -f tmp_${cvar}.nc
	    if [ ! -f tmp_${cvar}_${YEAR_I}.nc ] ; then
		if ${missval_extrapolate} ; then
		    cdo -setyear,${YEAR_I} tmp_${cvar}_$(( YEAR_I+1 )).nc tmp_${cvar}_${YEAR_I}.nc
		else
		    #cdo -setrtomiss,-inf,inf -setyear,${YEAR_I} tmp_${cvar}_${YEAR_END}.nc tmp_${cvar}_${YEAR_I}.nc
		    cdo -setrtoc,-inf,inf,nan -setyear,${YEAR_I} tmp_${cvar}_$(( YEAR_I+1 )).nc tmp_${cvar}_${YEAR_I}.nc
		fi
	    elif [ ! -f tmp_${cvar}_$(( YEAR_END+1 ))}.nc ] ; then
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
            cdo -O mergetime  tmp_${cvar}_????.nc tmp_${cvar}.nc
	    rm -f tmp_${cvar}_????.nc
	fi
    done

    # create the cTotal variable by adding cAtmos cLand and cOcean
    [ ${ccycle_pisces} == 1 ] && cdo selvar,cOcean ${SUPA_FILE3} tmp_cOcean.nc

    if [ ${ccycle_lpjg} == 1 ] && [ ${ccycle_tm5} == 1 ] && [ ${ccycle_pisces} == 1 ] ; then
	cdo -O -chvar,cOcean,cTotal -add tmp_cOcean.nc -add tmp_cLand.nc tmp_cAtmos.nc tmp_cTotal.nc
	ncatted -O -a long_name,cTotal,m,c,"Total Carbon in Atmosphere, Land and Ocean" tmp_cTotal.nc
    elif [ ${ccycle_lpjg} == 1 ] && [ ${ccycle_pisces} == 1 ] ; then
	cdo -O -chvar,cOcean,cTotal -add tmp_cOcean.nc tmp_cLand.nc tmp_cTotal.nc
	ncatted -O -a long_name,cTotal,m,c,"Total Carbon in Land and Ocean" tmp_cTotal.nc
    else
	echo "Not producing cTotal variable, modify monitor_ccycle.sh for your config"
    fi

    # merge all variables in one file
    cdo merge tmp_*.nc ${SUPA_FILE2}
    rm -f tmp_*.nc

    cd ..
    rm -rf ${TMPD}

    echo
    echo " Time series saved into:"
    echo " ${SUPA_FILE}"
    echo

    #Concatenate new and old files... 
    if [[ ! -z ${BASE_YEAR_INI} ]] ; then
         echo " Concatenate old and new netcdf files... " 
         ncrcat -h ${OLD_SUPA_FILE} ${SUPA_FILE} ${DIAG_D}/${RUN}_${BASE_YEAR_INI}_${YEAR_END}_time-series_ccycle.nc
         rm ${OLD_SUPA_FILE} ${SUPA_FILE}
	 # remove old SUPA_FILE2 and SUPA_FILE3
         rm ${OLD_SUPA_FILE2} ${OLD_SUPA_FILE3}
         export SUPA_FILE=${RUN}_${BASE_YEAR_INI}_${YEAR_END}_time-series_ccycle.nc
         echo " Variables saved in ${RUN}_${BASE_YEAR_INI}_${YEAR_END}_time-series_ccycle.nc " ; echo
    fi

fi # [ ${IPREPHTML} -eq 0 ]


if [ ${IPREPHTML} -eq 1 ]; then


    if [ ! -f ${SUPA_FILE} ]; then
        echo
        echo " PROBLEM: we cannot find ${SUPA_FILE} !!!"
        exit
    fi

    cd ${DIAG_D}/

    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series.py
    export SUPA_FILE=${SUPA_FILE2}
    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series2.py
    export SUPA_FILE=${SUPA_FILE3}
    ${PYTHON} ${HERE}/scripts/plot_ccycle_time_series2.py

    # Configuring HTML display file:
    sed -e "s/{TITLE}/Carbon cycle diagnostics for EC-Earth coupled experiment/g" \
        -e "s/{RUN}/${RUN}/g" -e "s/{DATE}/`date`/g" -e "s/{HOST}/`hostname`/g" \
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
