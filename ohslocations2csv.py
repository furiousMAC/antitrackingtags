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

reports = []

#Extract all datetimes
for i in range(len(lines)):
    if not "speed" in lines[i]:
        continue
    
    reported = lines[i+1].strip()
    date = lines[i+2].strip()[9:-1]
    accuracy = lines[i+3].strip()
    confidence = lines[i+4].strip()[9:-1]

    reports.append((dateutil.parser.parse(date), dateutil.parser.parse(reported), re.split("<|>", lines[i])[1], accuracy, confidence))

#Sort
reports.sort()

outfile.write("Time Seen,Time Reported,Lat,Long,Report Delay,Accuracy,Confidence")
outfile.write("\n")

for (s, r, l, a, c) in reports:
    outfile.write(str(s))
    outfile.write(",")
    outfile.write(str(r))
    outfile.write(",")
    outfile.write(l)
    outfile.write(",")
    outfile.write(str(r-s))
    outfile.write(",")
    outfile.write(a)
    outfile.write(",")
    outfile.write(c)
    outfile.write("\n")

outfile.close()

