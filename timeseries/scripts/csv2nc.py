import sys
import os
import numpy as np
from netCDF4 import Dataset, num2date, date2num
import csv

from datetime import date, time, datetime, timedelta

def Usage():
    print('usage: test.py csv_file nc_file')
    sys.exit( 1 )

if len(sys.argv) < 2:
    Usage()

ifile=sys.argv[1]
ofile=sys.argv[2]

if not os.path.exists(ifile):
    print('ifile '+ifile+' not found')
    Usage()

print('reading '+str(ifile))

# open csv file and to get # of rows
csv_file=open(ifile)
#csv_reader = csv.DictReader(csv_file, delimiter=' ', skipinitialspace=True)
csv_reader = csv.DictReader(csv_file)
count = sum(1 for _ in csv_reader)

ntimes = count


# create netcdf file with time dimension
# https://iescoders.com/writing-netcdf4-data-in-python/
ncfile = Dataset(ofile,mode='w',format='NETCDF3_CLASSIC') 
time_dim = ncfile.createDimension('time', None) # unlimited axis (can be appended to).
var_time = ncfile.createVariable('time', np.float64, ('time',))
var_time.units = 'hours since 1850-01-01 00:00:00'
var_time.calendar = 'proleptic_gregorian'
var_time.long_name = 'time'
var_time.standard_name = 'time'
data_time = np.zeros(ntimes)

# add variables
vars=dict()
data=dict()
for v in csv_reader.fieldnames:
    vars[v] = ncfile.createVariable(v,np.float64,('time'))
    data[v] = np.zeros(ntimes)


# parse csv files populating data arrays
csv_file.seek(0)
#csv_reader = csv.DictReader(csv_file, delimiter=' ', skipinitialspace=True)
csv_reader = csv.DictReader(csv_file)
#print(dir(csv_reader))
i=0
for row in csv_reader:
    data_time[i] = date2num(datetime.strptime(row['Year'], '%Y'),units=var_time.units,calendar=var_time.calendar)
    for v in csv_reader.fieldnames:
        data[v][i] = row[v] if row[v] is not "" else np.nan

    i=i+1


var_time[:] = data_time[:]
for v in csv_reader.fieldnames:
    vars[v][:] = data[v]    


ncfile.close()
print('wrote '+str(ofile))
