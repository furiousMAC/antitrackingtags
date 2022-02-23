#This program takes an advertisement key from OpenHaystack and converts it into an uncompressed form to be used in puckcode.js

import sys
import base64

def advertisement_template():
    adv = ""
    adv += "1e"  # length (30)
    adv += "ff"  # manufacturer specific data
    adv += "4c00"  # company ID (Apple)
    adv += "1219"  # offline finding type and length
    adv += "10"  # battery state, 0x10 is full battery
    for _ in range(22):  # key[6:28]
        adv += "00"
    adv += "00"  # first two bits of key[0]
    adv += "00"  # hint
    return bytearray.fromhex(adv)

if len(sys.argv) < 2:
    print("Usage: python3 ohs2puckjs.py <advertising key>")
    sys.exit(0)

key = base64.b64decode(sys.argv[1].encode())

addr = bytearray(key[:6])
addr[0] |= 0b11000000

adv = advertisement_template()
adv[7:29] = key[6:28]
adv[29] = key[0] >> 6

mac = addr.hex()

data = adv.hex()

payload = "{mac: \"";
mac = [mac[i]+mac[i+1] for i in range(0, len(mac), 2)]
payload += ":".join(mac)

payload += "\", data: [";

dbytes = ["0x" + data[i] + data[i+1] for i in range(0, len(data), 2)]

payload += ",".join(dbytes)

payload += "]}"
print(payload)