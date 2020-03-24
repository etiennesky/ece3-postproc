# L. Brodeau, november 2013

import sys
import os
import numpy as nmp
from netCDF4 import Dataset

# From BaraKuda python package:
import barakuda_orca as bo
import barakuda_plot as bp
import barakuda_tool as bt


CRUN = os.getenv('RUN')
if CRUN == None: print 'The RUN environement variable is no set'; sys.exit(0)

SUPA_FILE = os.getenv('SUPA_FILE')
if SUPA_FILE == None: print 'The SUPA_FILE environement variable is no set'; sys.exit(0)





#narg = len(sys.argv)
#if narg != 2: print 'Usage: '+sys.argv[0]+' <diag>'; sys.exit(0)
#cdiag = sys.argv[1]
#print '\n plot_time_series.py: diag => "'+cdiag+'"'






#v_var_names = [ 'msl', 'tas', 'totp', 'NetTOA', 'NetSFC', 'PminE', 'e', 'tcc', 'PminE', 'tsr', 'ssr' ]
v_var_names = [ 'cLand' , 'co2s', 'co2mass' ]
nbvar = len(v_var_names)

v_var_units = nmp.zeros(nbvar, dtype = nmp.dtype('a8'))
v_var_lngnm = nmp.zeros(nbvar, dtype = nmp.dtype('a64'))


print '\n *** plot_ccycle_time_series.py => USING time series in '+SUPA_FILE


bt.chck4f(SUPA_FILE)


# Reading all var in netcdf file:

id_clim = Dataset(SUPA_FILE)

vtime = id_clim.variables['time'][:]

nbr   = len(vtime)

XX = nmp.zeros(nbvar*nbr) ; XX.shape = [nbvar, nbr]

for jv in range(nbvar):
    print ' **** reading '+v_var_names[jv]
    #XX[jv,:] = id_clim.variables[v_var_names[jv]][:]
    XX[jv,:] = (id_clim.variables[v_var_names[jv]][:]).reshape((nbr))
    try:
        v_var_units[jv] = id_clim.variables[v_var_names[jv]].units
    except AttributeError:
        v_var_units[jv] = ""
    try:
        v_var_lngnm[jv] = id_clim.variables[v_var_names[jv]].long_name
    except AttributeError:
        v_var_lngnm[jv] = v_var_names[jv]

id_clim.close()




for jv in range(nbvar):

    cv  = v_var_names[jv]
    cln = v_var_lngnm[jv]
    cfn  = cv+'_'+CRUN

    print '   Creating figure '+cfn

    # Annual data
    VY, FY = bt.monthly_2_annual(vtime[:], XX[jv,:])

    ittic = bt.iaxe_tick(nbr/12)

    # Time to plot
    bp.plot_1d_mon_ann(vtime[:], VY, XX[jv,:], FY, cfignm=cfn, dt_year=ittic,
                          cyunit=v_var_units[jv], ctitle = CRUN+': '+cln,
                          cfig_type='svg', l_tranparent_bg=False)


sys.exit(0)

print 'plot_time_series.py done...\n'


##########################################
# Basic temp., sali. and SSH time series #
##########################################

if fig_id == 'simple':

    SUPA_FILE_m = cdiag+'_'+CRUN+'_global.dat'

    # Yearly data:
    #XY = bt.read_ascii_column(SUPA_FILE_y, [0, 1]) ; [ n0, nby ] = XY.shape

    # Monthly data:
    XM = bt.read_ascii_column(SUPA_FILE_m, [0, 1]) ; [ n0, nbm ] = XM.shape
    if nbm%12 != 0: print 'ERROR: plot_time_series.py => '+cdiag+', numberof records not a multiple of 12!', sys.exit(0)

    # Annual data
    VY, FY = bt.monthly_2_annual(XM[0,:], XM[1,:])

    ittic = bt.iaxe_tick(nbm/12)

    # Time to plot
    bp.plot_1d_mon_ann(XM[0,:], VY, XM[1,:], FY, cfignm=cdiag+'_'+CRUN, dt_year=ittic,
                         cyunit=cyu, ctitle = CRUN+': '+clnm, ymin=ym, ymax=yp)


print 'plot_time_series.py done...\n'
