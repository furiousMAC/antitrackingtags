#Takes an output file from FuriosTools batchfetch and turns it into a KML file with map data of the location reports

import sys
import re
import datetime

infile = open(sys.argv[1], "r")
outfile = open(sys.argv[2], "w")

lines = infile.readlines()

outfile.write("""<kml xmlns="http://www.opengis.net/kml/2.2">
   <Placemark>
     <name>OpenHaystack Path</name>
     <LineString>
         <altitudeMode>clampToGround</altitudeMode>
         <coordinates>\n""")

points = []

if len(sys.argv) == 4:
    cmin = int(sys.argv[3])
else:
    cmin = 5

for i in range(len(lines)):
    if not "speed" in lines[i]:
        continue
    coords = re.split("<|>", lines[i])[1]
    coords = coords.split(",")[1] + "," + coords.split(",")[0]
    time = re.split("\(|\)", lines[i+2])[1]
    day = datetime.date.fromisoformat(time.split()[0])
    time = time.split()[1]
    time = time.split(":")
    time = datetime.time(hour = int(time[0]), minute = int(time[1]), second = int(time[2]))
    confidence = int(lines[i+4][9:10])
    if confidence >= cmin:
        points.append((day, time, coords))

points.sort()


for (_, _, c) in points:
    print(c)
    outfile.write(c)
    outfile.write("\n")


outfile.write("""
         </coordinates>
     </LineString>
   </Placemark>
 </kml>""")
