import sys
import os
import numpy as np
from netCDF4 import Dataset, num2date, date2num
import csv

from datetime import date, time, datetime, timedelta

def Usage():
    print('usage: ocean_carbon_csv2nc.py csv_file_in nc_file_out csv_file_out')
    sys.exit( 1 )

if len(sys.argv) < 4:
    Usage()

ifile=sys.argv[1]
ofile_nc=sys.argv[2]
ofile_csv=sys.argv[3]

if not os.path.exists(ifile):
    print('ifile '+ifile+' not found')
    Usage()

print('reading '+str(ifile)+' and writing '+str(ofile_csv))

# open csv file to get # of rows and make copy without duplicates
csv_file_in=open(ifile)
csv_file_out=open(ofile_csv, 'w')
csv_reader = csv.DictReader(csv_file_in, delimiter=' ', skipinitialspace=True)
csv_writer = csv.DictWriter(csv_file_out, delimiter=' ', fieldnames=csv_reader.fieldnames)
csv_writer.writeheader()
#count = sum(1 for _ in csv_reader)
count=0
prev=None
for row in csv_reader:
    #print(row)
    # remove duplicates
    if prev==None or prev!=row['date']:
       count=count+1
       csv_writer.writerow(row)
    prev=row['date']
csv_file_in.close()
csv_file_out.close()

print(count)

# create netcdf file with time dimension
# https://iescoders.com/writing-netcdf4-data-in-python/
ncfile = Dataset(ofile_nc,mode='w',format='NETCDF3_CLASSIC') 
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

var_totc = ncfile.createVariable('cOceanYr',np.float64,('time'))
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

# initialize data and time arrays
#ntimes = count + 1 #add one for the first chunk
ntimes = count
data_time = np.zeros(ntimes)
data_totc = np.zeros(ntimes)
data_rivsed = np.zeros(ntimes)
data_fgco2 = np.zeros(ntimes)
data_corr = np.zeros(ntimes)

# parse csv files populating data arrays
# open csv file and to get # of rows
csv_file_in=open(ofile_csv)
csv_reader = csv.DictReader(csv_file_in, delimiter=' ', skipinitialspace=True)

i=0
for row in csv_reader:

    date1 = datetime.strptime(row['date'], '%Y%m%d')
    # this assumes yearly chunks, adapt if necessary - convert yyyy1231 to yyyy0101
    data_time[i] = date2num(datetime(date1.year,1,1),units=var_time.units,calendar=var_time.calendar)
    data_totc[i] = row['TotC-t1-PgC']
    data_rivsed[i] = row['riv+sed-PgC']
    data_fgco2[i] = row['fgco2-PgC']
    data_corr[i] = row['corr-PgC']

    i=i+1


#print(data_time)
#print(data_totc)

var_time[:] = data_time[:]
var_totc[:] = data_totc
var_rivsed[:] = data_rivsed
var_fgco2[:] = data_fgco2
var_corr[:] = data_corr


ncfile.close()
print('wrote '+str(ofile_nc))
