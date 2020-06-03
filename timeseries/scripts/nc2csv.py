import sys
import os
import numpy as np
from netCDF4 import Dataset, num2date, date2num
import csv

from datetime import date, time, datetime, timedelta

def Usage():
    print('usage: test.py nc_file csv_file')
    sys.exit( 1 )

if len(sys.argv) < 2:
    Usage()

ifile=sys.argv[1]
ofile=sys.argv[2]

if not os.path.exists(ifile):
    print('ifile '+ifile+' not found')
    Usage()

#print('reading '+str(ifile))


ncfile = Dataset(ifile,mode='r') 
times = ncfile.variables['time']
dates = num2date(times[:],units=times.units,calendar=times.calendar)[:]
vars = ncfile.variables
dims = ncfile.dimensions


#print(times)
#print(dates)
#print(vars.keys())


# create csv file and write header
csv_file = open(ofile, 'w')
#fieldnames = [u'date']
fieldnames = []
vars_excluded = [ 'time', 'lat', 'lon', 'depth', 'plev' ]
for var in vars.keys():
    if var not in dims and var not in vars_excluded:
        fieldnames.append(var)
#print(fieldnames)
#print(str(fieldnames))

csv_writer = csv.DictWriter(csv_file, delimiter=' ', fieldnames=[u"date"]+fieldnames)
csv_writer.writeheader()

for i in range(len(times)):
#    print(i)
    d = dict()
    d[u"date"] = "{0.year:4d}{0.month:02d}{0.day:02d}".format(dates[i])
    for f in fieldnames:
        d[f] = ncfile.variables[f][i].reshape(1)[0]
    csv_writer.writerow(d)
