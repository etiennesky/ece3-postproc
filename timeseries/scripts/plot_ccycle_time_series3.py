
import sys
import os
import numpy as nmp
from netCDF4 import Dataset, num2date

# From BaraKuda python package:
import barakuda_orca as bo
import barakuda_plot as bp
import barakuda_tool as bt


CRUN = os.getenv('RUN')
if CRUN == None: print 'The RUN environement variable is no set'; sys.exit(1)

SUPA_FILE = os.getenv('SUPA_FILE')
if SUPA_FILE == None: print 'The SUPA_FILE environement variable is no set'; sys.exit(1)

CCYCLE_TM5 = os.getenv('CCYCLE_TM5')
if CCYCLE_TM5 == None: print 'The CCYCLE_TM5 environement variable is no set'; sys.exit(1)
ccycle_tm5 = ( CCYCLE_TM5 == "1" )

outfile_suffix = os.getenv('OUTFILE_SUFFIX')
if outfile_suffix == None: print 'The OUTFILE_SUFFIX environement variable is no set'; sys.exit(1)


print '\n *** plot_ccycle_time_series3.py => USING time series in '+SUPA_FILE


#narg = len(sys.argv)
#if narg != 2: print 'Usage: '+sys.argv[0]+' <diag>'; sys.exit(1)
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
ittic = bt.iaxe_tick(nbr,10)

vars_excluded = [ 'time', 'lat', 'lon', 'depth', 'Year' ]
vars_cpool = [ 'cLand', 'cVeg', 'cProduct', 'cLitter', 'cSoil' ]
vars_cflux = [ 'gpp', 'npp', 'nep', 'nbp' ]

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
XX_cumm = nmp.zeros(nbvar*nbr) ; XX_cumm.shape = [nbvar, nbr]
XX_drift = nmp.zeros(nbvar*nbr) ; XX_drift.shape = [nbvar, nbr]

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

    # compute cummulative values and cumulative drift
    if nbr > 1:

        # compute cummulative values
        XX_cumm[jv,0] = 0 if nmp.isnan(XX[jv,0]) else XX[jv,0]
        for i in range(nbr):
            if i > 0 :
                XX_cumm[jv,i] = XX_cumm[jv,i-1] if nmp.isnan(XX[jv,i]) else XX_cumm[jv,i-1] + XX[jv,i] 
    
        # compute cummulative drift values
        inival = XX[jv,1] if nmp.isnan(XX[jv,0]) else XX[jv,0]
        XX_drift[jv,0] = 0
        for i in range(nbr):
            if i > 0 :
                XX_drift[jv,i] = XX_drift[jv,i-1] if nmp.isnan(XX[jv,i]) else XX[jv,i] - inival

id_clim.close()



cfn  = 'carbon_land_'+outfile_suffix+'_'+CRUN
if outfile_suffix != 'flux':
    vars_ = vars_cpool
    ct = CRUN+" / land carbon pools / "+outfile_suffix
else:
    vars_ = vars_cflux
    ct = CRUN+" / land carbon fluxes"
cyunit='Pg C'
print '   Creating figure '+cfn
bp.plot_1d_ann_multi(vtime[:], XX, v_var_names, vars_, cfignm=cfn, dt_year=ittic,
                     cyunit=cyunit, ctitle = ct,
                     cfig_type='svg', l_tranparent_bg=False, plot_drift=0.1)

if outfile_suffix != 'flux':
    cfn  = 'drift_carbon_land_'+outfile_suffix+'_'+CRUN
    ct = CRUN+" / land carbon drift / "+outfile_suffix
    cyunit='Pg C'
    print '   Creating figure '+cfn
    bp.plot_1d_ann_multi(vtime[:], XX_drift, v_var_names, vars_cpool, cfignm=cfn, dt_year=ittic,
                         cyunit=cyunit, ctitle = ct,
                         cfig_type='svg', l_tranparent_bg=False, plot_drift=0.1)


print 'plot_time_series.py done...\n'

