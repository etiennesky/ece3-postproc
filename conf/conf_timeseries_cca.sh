#!/bin/ksh

 ###############################################################################
 # Configuration file for timeseries script                                    #
 #                                                                             #
 # Add here machine dependent set up that do NOT necessarily depends on any of #
 #    the following sticky general user settings:                              #
 #    ECE3_POSTPROC_TOPDIR, ECE3_POSTPROC_RUNDIR, or ECE3_POSTPROC_DATADIR     #
 ###############################################################################

# Where to store produced time-series (<RUN>, if used, is replaced by the experiment 4-letter name)

export EMOP_CLIM_DIR=${HOME}/EC-Earth3/diag/
mkdir -p $EMOP_CLIM_DIR

export DIR_TIME_SERIES="${EMOP_CLIM_DIR}/timeseries/<RUN>"


# where to find mesh and mask files for NEMO. Files are expected in $MESHDIR_TOP/$NEMOCONFIG.
export MESHDIR_TOP="/perm/ms/nl/nm6/ECE3-DATA/post-proc"

# About web page, on remote server host:
#     =>  set RHOST="" to disable this function...
export RHOST=""
export RUSER=""
export WWW_DIR_ROOT=""

############################
# Required software   #
############################

#PLS module switch PrgEnv-cray PrgEnv-intel
module load nco netcdf python cdo cdftools

# support for GRIB_API?
# Set the directory where the GRIB_API tools are installed
# Note: cdo had to be compiled with GRIB_API support for this to work
# This is only required if your highest level is above 1 hPa,
# otherwise leave GRIB_API_BIN empty (or just comment the line)!
# export GRIB_API_BIN="/home/john/bin"

# The CDFTOOLS set of executables should be found into:
export CDFTOOLS_BIN="${CDFTOOLS_DIR}/bin"

# The rebuild_nemo (provided with NEMO), that somebody has built (relies on flio_rbld.exe):
export RBLD_NEMO="${PERM}/r1902-merge-new-components/sources/nemo-3.6/TOOLS/REBUILD_NEMO/rebuild_nemo"

export PYTHON=python
export cdo=cdo
