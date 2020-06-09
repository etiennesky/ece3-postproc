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
if CRUN == None: print 'The RUN environement variable is no set'; sys.exit(1)

SUPA_FILE = os.getenv('SUPA_FILE')
if SUPA_FILE == None: print 'The SUPA_FILE environement variable is no set'; sys.exit(1)

PLOT_DRIFT = os.getenv('PLOT_DRIFT')
if PLOT_DRIFT == None: print 'The PLOT_DRIFT environement variable is no set'; sys.exit(1)
plot_drift = ( PLOT_DRIFT == "true" )

CCYCLE_TM5 = os.getenv('CCYCLE_TM5')
if CCYCLE_TM5 == None: print 'The CCYCLE_TM5 environement variable is no set'; sys.exit(1)
ccycle_tm5 = ( CCYCLE_TM5 == "1" )

ccycle_emiss_fixyear = os.getenv('CCYCLE_EMISS_FIXYEAR')
if ccycle_emiss_fixyear == None: print 'The CCYCLE_EMISS_FIXYEAR environement variable is no set'; sys.exit(1)


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
ittic = bt.iaxe_tick(nbr,10)

#v_var_names = [ 'msl', 'tas', 'totp', 'NetTOA', 'NetSFC', 'PminE', 'e', 'tcc', 'PminE', 'tsr', 'ssr' ]
#v_var_names = [ 'cLand' , 'co2s', 'co2mass' ]
#v_var_names = [ 'cOcean', 'fgco2', 'rivsed', 'corr' ]

vars_fluxes_invert = [ 'fgco2', 'rivsed_p4z' ]
vars_excluded = [ 'time', 'lat', 'lon', 'depth', 'Year' ]
vars_fluxes = [ 'fco2nat', 'fco2antt', 'fgco2-', 'fCLandToOcean', 'rivsed_p4z-' ]
vars_fluxes2 = [ 'fLandYr', 'fOceanYr', 'fGeoYr' ]
vars_cpool = [ 'cLand', 'cVeg', 'cProduct', 'cLitter', 'cSoil' ]
if ccycle_tm5:
    vars_drift = [ 'cLandYr', 'cOceanYr', 'cAtmosYr', 'cGeoYr', 'cTotalYr' ]
    vars_drift_cumm = vars_drift
    if ccycle_emiss_fixyear == "0":
    #    vars_drift_cumm.append('fco2fos')
        vars_fluxes.append('fco2fos')
else:
    vars_drift = [ 'cLandYr', 'cOceanYr', 'cGeoYr', 'cTotalYr' ]
    vars_drift_cumm = vars_drift
# cAtmos cFlux cLand cLand1 cOcean cTotal co2mass co2s fco2antt fco2fos fco2nat fgco2 nbp nep


#print("ccycle_tm5: "+str(ccycle_tm5))
#print("ccycle_emiss_fixyear: "+str(ccycle_emiss_fixyear))
#print("vars_fluxes: "+str(vars_fluxes))
#print("vars_drift: "+str(vars_drift))
#print("vars_drift_cumm: "+str(vars_drift_cumm))

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

    if v_var_names[jv] in vars_fluxes_invert:
        XX[jv,:] = - XX[jv,:]
        v_var_names[jv] = v_var_names[jv] + u"-" 

    # compute cummulative values and cumulative drift
    if nbr > 1:

        # compute cummulative values
        XX_cumm[jv,0] = 0 if nmp.isnan(XX[jv,0]) else XX[jv,0]
        for i in range(nbr):
            if i > 0 :
                XX_cumm[jv,i] = XX_cumm[jv,i-1] if nmp.isnan(XX[jv,i]) else XX_cumm[jv,i-1] + XX[jv,i] 
    
        # compute drift values
        inival = XX[jv,1] if nmp.isnan(XX[jv,0]) else XX[jv,0]
        XX_drift[jv,0] = 0
        for i in range(nbr):
            if i > 0 :
                XX_drift[jv,i] = XX_drift[jv,i-1] if nmp.isnan(XX[jv,i]) else XX[jv,i] - inival

        # replace the fco2fos drift value with cumulative value so we can plot together with the drifts
        if v_var_names[jv] == "fco2fos":
            XX_drift[jv,:] = XX_cumm[jv,:]       
        

id_clim.close()



if plot_drift:
   
    cfn  = 'fluxes_year_'+CRUN
    ct = CRUN+" / fluxes"
    cyunit='Pg C'
    #print '   Creating figure '+cfn
    bp.plot_1d_ann_multi(vtime[:], XX, v_var_names, vars_fluxes, cfignm=cfn, dt_year=ittic,
                          cyunit=cyunit, ctitle = ct,
                          cfig_type='svg', l_tranparent_bg=False)

    cfn  = 'fluxes_cumm_year_'+CRUN
    ct = CRUN+" / cummulative fluxes"
    cyunit='Pg C'
    #print '   Creating figure '+cfn
    bp.plot_1d_ann_multi(vtime[:], XX_cumm, v_var_names, vars_fluxes, cfignm=cfn, dt_year=ittic,
                          cyunit=cyunit, ctitle = ct,
                          cfig_type='svg', l_tranparent_bg=False)

    cfn  = 'fluxes2_year_'+CRUN
    ct = CRUN+" / fluxes2"
    cyunit='Pg C'
    #print '   Creating figure '+cfn
    bp.plot_1d_ann_multi(vtime[:], XX, v_var_names, vars_fluxes2, cfignm=cfn, dt_year=ittic,
                          cyunit=cyunit, ctitle = ct,
                          cfig_type='svg', l_tranparent_bg=False)

    cfn  = 'fluxes2_cumm_year_'+CRUN
    ct = CRUN+" / cummulative fluxes2"
    cyunit='Pg C'
    #print '   Creating figure '+cfn
    bp.plot_1d_ann_multi(vtime[:], XX_cumm, v_var_names, vars_fluxes2, cfignm=cfn, dt_year=ittic,
                          cyunit=cyunit, ctitle = ct,
                          cfig_type='svg', l_tranparent_bg=False)

    cfn  = 'carbon_pools_year_'+CRUN
    ct = CRUN+" / carbon pools"
    cyunit='Pg C'
    #print '   Creating figure '+cfn
    bp.plot_1d_ann_multi(vtime[:], XX, v_var_names, vars_drift, cfignm=cfn, dt_year=ittic,
                          cyunit=cyunit, ctitle = ct,
                          cfig_type='svg', l_tranparent_bg=False, plot_drift=0.1)

    cfn  = 'drift_cumm_year_'+CRUN
    ct = CRUN+" / cummulative drift"
    cyunit='Pg C'
    #print '   Creating figure '+cfn
    bp.plot_1d_ann_multi(vtime[:], XX_drift, v_var_names, vars_drift_cumm, cfignm=cfn, dt_year=ittic,
                          cyunit=cyunit, ctitle = ct,
                          cfig_type='svg', l_tranparent_bg=False, plot_drift=0.1)

#    cfn  = 'carbon_land_'+CRUN
#    ct = CRUN+" / land carbon pools"
#    cyunit='Pg C'
#    print '   Creating figure '+cfn
#    bp.plot_1d_ann_multi(vtime[:], XX, v_var_names, vars_cpool, cfignm=cfn, dt_year=ittic,
#                          cyunit=cyunit, ctitle = ct,
#                          cfig_type='svg', l_tranparent_bg=False, plot_drift=0.1)

#    cfn  = 'drift_carbon_land_'+CRUN
#    ct = CRUN+" / land carbon drift"
#    cyunit='Pg C'
#    print '   Creating figure '+cfn
#    bp.plot_1d_ann_multi(vtime[:], XX_drift, v_var_names, vars_cpool, cfignm=cfn, dt_year=ittic,
#                          cyunit=cyunit, ctitle = ct,
#                          cfig_type='svg', l_tranparent_bg=False, plot_drift=0.1)


for jv in range(nbvar):
    
    cv  = v_var_names[jv]
    cln = v_var_lngnm[jv]
    cfn  = cv+'_year_'+CRUN
    cfn_drift  = cv+'_year_drift_'+CRUN
    ct = CRUN+' / '+cv+" : " +cln
    ct_drift = CRUN+' / '+cv+" drift"

    #print '   Creating figure '+cfn

    # Annual data
    #VY, FY = bt.monthly_2_annual(vtime[:], XX[jv,:])

    #ittic = bt.iaxe_tick(nbr/12)
    #ittic = bt.iaxe_tick(nbr,10)

    # Time to plot
    #bp.plot_1d_mon_ann(vtime[:], VY, XX[jv,:], FY, cfignm=cfn, dt_year=ittic,
    bp.plot_1d_ann(vtime[:], XX[jv,:], cfignm=cfn, dt_year=ittic,
                          cyunit=v_var_units[jv], ctitle = ct,
                          cfig_type='svg', l_tranparent_bg=False)

    if plot_drift and cv in vars_drift:
        print 'plotting drift for '+str(cv)
        #ymin = -0.3 if cv != 'cOcean' else -0.5
#        ymin = -0.5
        ymin = -1
        ymax = -ymin
        plot_drift1 = True
        #plot_drift20 = True if ( cv != 'cLand' and cv != 'cLand1' ) else False
        plot_drift20 = True
        plot_drift100 = True
        # TODO check plots have same range, dt_year param seems to influence this
        #bp.plot_1d_ann_drift(vtime[:], XX[jv,:], cfignm=cfn_drift, dt_year=ittic*2,
        bp.plot_1d_ann_drift(vtime[:], XX[jv,:], cfignm=cfn_drift, dt_year=ittic,
                             cyunit=v_var_units[jv], ctitle = ct_drift,
                             cfig_type='svg', l_tranparent_bg=False, 
                             ymin=ymin, ymax=ymax,
                             plot_drift1=plot_drift1,plot_drift20=plot_drift20,plot_drift100=plot_drift100 )

print 'plot_time_series.py done...\n'

