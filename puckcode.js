//Payload array
//Each element has a MAC address to use for the advertising message plus
//an array of data to send (advertisement keys created from OpenHaystack)

//Need to insert payloads before running on a puck
payloads = [];


//Index of currently broadcasting payload
pindex = 0;

//Save our true address for reconnecting
myAddr = NRF.getAddress();
// Identify device MAC address by bringing an NFC device into close proximity
addrAry = [0xd1, 0x01, 0x16, 0x55, 0x0 ].concat([].map.call("MAC-" + myAddr, x => x.charCodeAt(0)));
NRF.nfcRaw( new Uint8Array(addrAry) );

//Sets the payload to broadcast, from payload array
function setPayload(index){
  pindex = index;
  NRF.setTxPower(4);
  NRF.setAddress(payloads[index][0] + " random");
  data = atob(payloads[index][1]);
  console.log(data);
  data = data.split('');
  console.log(data);
  NRF.setAdvertising(data,
  {"showName": false, "interval": 2000, "connectable": false, "scannable": false});
}

//Flashes a combination of the 3 LEDs based on the bits set in binary argument 'pattern'
function flash(pattern) {
  digitalWrite([LED1, LED2, LED3], pattern);
  setTimeout(function() {
    digitalWrite([LED1, LED2, LED3], 0);
  }, 200);
}

//Disables advertising and allows reconnecting
function disableAdvertising(){
  flash(1); // Blue LED
  setTimeout(function(){   
    NRF.setTxPower(0);
    NRF.setAdvertising({}, {"showName": true, "connectable": true, "scannable": true});
    NRF.setAddress( myAddr + " random"); // Restore original HW Address
  }, 1000);
}

//Reads out the index of the currently broadcasting key
//Blinks a number of times equal to the key index + 1
function readIndex(){
  for( i = 0; i < pindex+1; i++ ){
    setTimeout(flash, i*500, 6); // Red & Green LEDs
  }
}

//Randomizes the primary key byte at the end of the payload
function randomPi(){
  data = atob(payloads[pindex][1]).split('');
  data[data.length-1] = Math.floor(Math.random()*255);
  console.log(data);
  NRF.setAdvertising(data,
  {"showName": false, "interval": 2000, "connectable": false, "scannable": false});
}

function rotateKey(){
  pindex = (pindex + 1) % payloads.length;
  setPayload(pindex);
  randomPi();
}

//Callback for button presses to blink out the key
setWatch(function(e) {
  if (e.time-e.lastTime > 1){
    disableAdvertising();
  }
  else readIndex();
}, BTN, { repeat: true, edge: 'falling', debounce:50});

// Disconnect from the host device to allow the Puck to change NRF characteristics
NRF.disconnect();

//Start broadcasting the first payload
setPayload(0);
randomPi();

setInterval(rotateKey, 900000);

//Set key byte to randomize every 15 minutes
//setInterval(randomPi, 900000);
