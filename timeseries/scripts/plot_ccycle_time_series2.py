# L. Brodeau, november 2013

import sys
import os
import numpy as nmp
from netCDF4 import Dataset, num2date

# From BaraKuda python package:
import barakuda_orca as bo
import barakuda_plot as bp
import barakuda_tool as bt


CRUN = os.getenv('RUN')
if CRUN == None: print 'The RUN environement variable is no set'; sys.exit(0)

SUPA_FILE = os.getenv('SUPA_FILE')
if SUPA_FILE == None: print 'The SUPA_FILE environement variable is no set'; sys.exit(0)

print '\n *** plot_ccycle_time_series2.py => USING time series in '+SUPA_FILE


#narg = len(sys.argv)
#if narg != 2: print 'Usage: '+sys.argv[0]+' <diag>'; sys.exit(0)
#cdiag = sys.argv[1]
#print '\n plot_time_series.py: diag => "'+cdiag+'"'


bt.chck4f(SUPA_FILE)


# Reading all var in netcdf file:

id_clim = Dataset(SUPA_FILE)

#vtime = id_clim.variables['time'][:]
times = id_clim.variables['time']
dates = num2date(times[:],units=times.units,calendar=times.calendar)[:]
vtime = nmp.zeros(len(dates))
for jv in range(len(dates)):
    vtime[jv] = dates[jv].year


nbr   = len(vtime)

#v_var_names = [ 'msl', 'tas', 'totp', 'NetTOA', 'NetSFC', 'PminE', 'e', 'tcc', 'PminE', 'tsr', 'ssr' ]
#v_var_names = [ 'cLand' , 'co2s', 'co2mass' ]
#v_var_names = [ 'cOcean', 'fgco2', 'rivsed', 'corr' ]

vars_excluded = [ 'time', 'lat', 'lon', 'depth', 'Year' ]
vars_drift = [ 'cLand', 'cOcean', 'cAtmos', 'cTotal' ]

# get all variables which are not dimensions
vars = id_clim.variables
dims = id_clim.dimensions
v_var_names=[]
for var in vars.keys():
    if var not in dims and var not in vars_excluded:
        v_var_names.append(var)

nbvar = len(v_var_names)
v_var_units = nmp.zeros(nbvar, dtype = nmp.dtype('a8'))
v_var_lngnm = nmp.zeros(nbvar, dtype = nmp.dtype('a64'))

print(str(nbvar)+" vars:")
print(v_var_names)


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
    try:
        missval = id_clim.variables[v_var_names[jv]].missing_value
    except AttributeError:
        missval = None
    if not missval is None:
        XX[jv,:]  = nmp.ma.masked_where(XX[jv,:]==missval, XX[jv,:])
        #print("got missval: "+str(missval))
        #print(XX[jv,:])

id_clim.close()


for jv in range(nbvar):

    cv  = v_var_names[jv]
    cln = v_var_lngnm[jv]
    cfn  = cv+'_year_'+CRUN
    cfn_drift  = cv+'_year_drift_'+CRUN
    ct = CRUN+' / '+cv+" : " +cln
    ct_drift = CRUN+' / '+cv+" drift"

    print '   Creating figure '+cfn

    # Annual data
    #VY, FY = bt.monthly_2_annual(vtime[:], XX[jv,:])

    #ittic = bt.iaxe_tick(nbr/12)
    ittic = bt.iaxe_tick(nbr)

    # Time to plot
    #bp.plot_1d_mon_ann(vtime[:], VY, XX[jv,:], FY, cfignm=cfn, dt_year=ittic,
    bp.plot_1d_ann(vtime[:], XX[jv,:], cfignm=cfn, dt_year=ittic,
                          cyunit=v_var_units[jv], ctitle = ct,
                          cfig_type='svg', l_tranparent_bg=False)

    if cv in vars_drift:
        print 'plotting drift for '+str(cv)
        ymin = -0.3 if cv != 'cOcean' else -0.5
        ymax = -ymin
        plot_drift1 = True
        plot_drift20 = True if cv != 'cLand' else False
        plot_drift100 = True
        bp.plot_1d_ann_drift(vtime[:], XX[jv,:], cfignm=cfn_drift, dt_year=ittic*2,
                             cyunit=v_var_units[jv], ctitle = ct_drift,
                             cfig_type='svg', l_tranparent_bg=False, 
                             ymin=ymin, ymax=ymax,
                             plot_drift1=plot_drift1,plot_drift20=plot_drift20,plot_drift100=plot_drift100 )

print 'plot_time_series.py done...\n'

