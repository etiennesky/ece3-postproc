import sys
import os
import numpy as np
from netCDF4 import Dataset, num2date, date2num
import csv

from datetime import date, time, datetime, timedelta

def Usage():
    print('usage: ocean_carbon_csv2nc.py csv_file nc_file')
    sys.exit( 1 )

if len(sys.argv) < 2:
    Usage()

ifile=sys.argv[1]
ofile=sys.argv[2]

if not os.path.exists(ifile):
    print('ifile '+ifile+' not found')
    Usage()

print('reading '+str(ifile))

# create cetcdf file with time dimension
# https://iescoders.com/writing-netcdf4-data-in-python/
ncfile = Dataset(ofile,mode='w',format='NETCDF3_CLASSIC') 
time_dim = ncfile.createDimension('time', None) # unlimited axis (can be appended to).
var_time = ncfile.createVariable('time', np.float64, ('time',))
var_time.units = 'hours since 1850-01-01 00:00:00'
var_time.calendar = 'proleptic_gregorian'
var_time.long_name = 'time'
var_time.standard_name = 'time'

# add variables
#{'TotC-t1-PgC': '1', 'corr-PgC': '5.00530', 'fgco2-PgC': '5.00478', 'riv+sed-PgC': '-5.00241', 'TotC-t2-PgC': '2', 'date': '18501231'}
#temp = ncfile.createVariable('temp',np.float64,('time'))
#temp.units = 'K' # degrees Kelvin
#temp.standard_name = 'air_temperature' # this is a CF standard name

var_totc = ncfile.createVariable('cOcean',np.float64,('time'))
var_totc.units = 'Pg C'
var_totc.long_name = 'Total Carbon in Ocean (PISCES)'
#var_totc.standard_name = 'cOcean'

var_fgco2 = ncfile.createVariable('fgco2_p4z',np.float64,('time'))
var_fgco2.units = 'Pg C'
var_fgco2.long_name = "Surface Downward Flux of Total CO2 (PISCES)"
var_fgco2.standard_name = "surface_downward_mass_flux_of_carbon_dioxide_expressed_as_carbon"

var_rivsed = ncfile.createVariable('rivsed_p4z',np.float64,('time'))
var_rivsed.units = 'Pg C'
var_rivsed.long_name = 'River input - Sedimentation (PISCES)'

var_corr = ncfile.createVariable('corr_p4z',np.float64,('time'))
var_corr.units = 'Pg C'
var_corr.long_name = 'C mass damping flux (PISCES)'

# open csv file and to get # of rows
csv_file=open(ifile)
csv_reader = csv.DictReader(csv_file, delimiter=' ', skipinitialspace=True)
count = sum(1 for _ in csv_reader)


# initialize data and time arrays
ntimes = count + 1 #add one for the first chunk
data_time = np.zeros(ntimes)
data_totc = np.zeros(ntimes)
data_rivsed = np.zeros(ntimes)
data_fgco2 = np.zeros(ntimes)
data_corr = np.zeros(ntimes)

# parse csv files populating data arrays
csv_file.seek(0)
csv_reader = csv.DictReader(csv_file, delimiter=' ', skipinitialspace=True)
#print(dir(csv_reader))
i=0
for row in csv_reader:
    #print type(row)
    #print row
    # adjust date by 1 day
    date1 = datetime.strptime(row['date'], '%Y%m%d')
    date2 = date1+timedelta(days=1)
#        print("{0.year:4d}{0.month:02d}{0.day:02d}".format(date1))
#        print("{0.year:4d}{0.month:02d}{0.day:02d}".format(date2))
    #row['date'] = "{0.year:4d}{0.month:02d}{0.day:02d}".format(date2)
    #print row
    #print (row['date']+' - '+row['TotC-t1-PgC'])

    #data_time[i] = "{0.year:4d}{0.month:02d}{0.day:02d}".format(date2) #row['date']
    #data_time[i] = date2 #row['date']

    # this assumes yearly chunks, adapt if necessary
    if (i==0):
        date0 = datetime(date1.year,1,1)
        data_time[i] = date2num(date0,units=var_time.units,calendar=var_time.calendar)
        data_totc[i] = row['TotC-t1-PgC']
        data_rivsed[i] = 0 #row['riv+sed-PgC']
        data_fgco2[i] = 0 #row['fgco2-PgC']
        data_corr[i] = 0 #row['corr-PgC']
        i=i+1

    data_time[i] = date2num(date2,units=var_time.units,calendar=var_time.calendar)
    data_totc[i] = row['TotC-t2-PgC']
    data_rivsed[i] = row['riv+sed-PgC']
    data_fgco2[i] = row['fgco2-PgC']
    data_corr[i] = row['corr-PgC']

    i=i+1


#print(data_totc)
#print(data_time)

var_time[:] = data_time[:]
var_totc[:] = data_totc
var_rivsed[:] = data_rivsed
var_fgco2[:] = data_fgco2
var_corr[:] = data_corr


ncfile.close()
print('wrote '+str(ofile))
