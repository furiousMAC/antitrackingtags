Proof of concept implementation from the paper "Who Tracks the Trackers? Circumventing Apple's Anti-Tracking Alerts in the Find My Network" published at WPES 2021.

Full paper: https://samteplov.com/uploads/who-tracks-the-trackers/trackers.pdf

## Files

- puckcode.js - Javascript code for an Espruino device (Puck.js) that implements method #2 from the paper, a fixed list of public keys that are rotated through over time.  Keys can be generated from FuriousTools using the batchgen command, or one-by-one using vanilla OpenHaystack and exporting the advertisement key.
- puck_ec_firmware.zip - A custom firmware for Espruino that provides the function PointGen which is necessary for ecpuckcode.js.
- ecpuckcode.js - Javascript code for an Espruino device that implements method #3 from the paper, psuedorandomly generated public keys.  Requires additional elliptic curve math that Espruino does not normally have, the EC firmware above must be loaded.
- FuriousTools - Command line extension for OpenHaystack that allows for easy access to the key generation and report retrieval functionality.  Can be added to OpenHaystack by creating a new command line target in Xcode and putting in the main.swift file from the FuriousTools folder.
- ohs*.py - Python scripts for converting between the output format of OpenHaystack and what we need/want for the Espruino.