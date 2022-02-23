#Takes an output file from FuriosTools batchfetch and creates a histogram of # of reports per time slice
#Optional third argument is the time slice length in seconds

import sys
import re
import datetime
import dateutil.parser

infile = open(sys.argv[1], "r")
outfile = open(sys.argv[2], "w")

slice = 60

if(len(sys.argv) == 4):
    slice = int(sys.argv[3])

lines = infile.readlines()
infile.close()

times = []

#Extract all datetimes
for i in range(len(lines)):
    if not "Optional" in lines[i]:
        continue
    
    date = lines[i].strip()[9:-1]

    times.append(dateutil.parser.parse(date))

#Sort
times.sort()

#Calculate total time distance
starttime = times[0]
timelength = (times[-1] - times[0]).seconds

for i in range(0, timelength, slice):
    count = 0
    while(len(times) > 0 and (times[0]- starttime).seconds <= i):
        count += 1
        del(times[0])
    outfile.write(str(i))
    outfile.write(",")
    outfile.write(str(count))
    outfile.write("\n")

outfile.close()

