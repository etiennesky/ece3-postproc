#!/bin/bash

# Configuration file for hiresclim script
# 
# Add here machine dependent set up that do NOT necessarily depends on any of
#    the following general user settings:
#    ECE3_POSTPROC_TOPDIR, ECE3_POSTPROC_RUNDIR, or ECE3_POSTPROC_DATADIR

# required programs, including compression options
module load nco netcdf python cdo cdftools

cdo=cdo
cdozip="$cdo -f nc4c -z zip"
rbld="/perm/ms/nl/nm6/r1902-merge-new-components/sources/nemo-3.6/TOOLS/REBUILD_NEMO/rebuild_nemo"
#rbld="/perm/ms/spesiccf/c3et/REBUILD_NEMO/rebuild_nemo"

cdftoolsbin="${CDFTOOLS_DIR}/bin"
#cdftoolsbin="/home/ms/nl/nm6/ECEARTH/postproc/barakuda/cdftools_light/bin"
python=python

# number of parallel procs for IFS (max 12) and NEMO rebuild. Default to 12.
if [ -z $IFS_NPROCS ] ; then
    IFS_NPROCS=12; NEMO_NPROCS=12
fi

# where to find mesh and mask files for NEMO. Files are expected in $MESHDIR_TOP/$NEMOCONFIG.
export MESHDIR_TOP="/perm/ms/nl/nm6/ECE3-DATA/post-proc"
#export MESHDIR_TOP="/perm/ms/spesiccf/c3et/ece3-postproc"

# Base dir to archive (ie just make a copy of) the monthly results. Daily results, if any, are left in scratch. 
#STOREDIR=/home/hpc/pr45de/di56bov/work/ecearth3/post/hiresclim/
STOREDIR=${SCRATCH}/ecearth3/post/hiresclim-test

# TODO: implement a true backup on ECFS


# process 3D vars (most of which which are in SH files) ? 
# set to 0 if you only want simple diags e.g. Gregory plots
# currently only used in ifs_monthly_prim.sh
export do_3d_vars=0

