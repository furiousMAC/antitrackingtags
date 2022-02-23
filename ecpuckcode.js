//Code for method #3, pseudorandomly generated public keys from a secret seed
//Requires custom firmware installed on Puck to provide EC functions (puck_ec_firmware.zip)

function parseHexString(str) 
{ 
    var result = [];
    while (str.length >= 2) 
    { 
        result.push(parseInt(str.substring(0, 2), 16));

        str = str.substring(2, str.length);
    }

    return result;
}

function createHexString(arr) {
    var result = "";
    var z;

    for (var i = 0; i < arr.length; i++) {
        var str = arr[i].toString(16);

        z = 2 - str.length + 1;
        str = Array(z).join("0") + str;

        result += str;
    }

    return result;
}

function setAdvertising(key){
  data = "1eff4c00121910000000000000000000000000000000000000000000000000";
  databytes = parseHexString(data);
  console.log(key);
  keybytes = parseHexString(key);
  addressbytes = keybytes.slice(0,6);
  addressbytes[0] |= 192;
  
  for(x = 7; x < 29; x++){
    databytes[x] = keybytes[x-1];
  }
  
  databytes[29] = keybytes[0] >> 6;
  
  address = createHexString(addressbytes);
  mac = "";
  for(x = 0; x < 12; x += 2){
    mac += address.slice(x, x+2);
    mac += ":";
  }
  mac = mac.slice(0, mac.length-1);
  
  console.log(mac);
  
  NRF.setTxPower(4);
  NRF.setAddress(mac + " random");
  
  console.log(databytes);
  
  NRF.setAdvertising(databytes,
  {"showName": false, "interval": 2000, "connectable": false, "scannable": false});
}

function rotateKey(){
  seed = seed1 + seed2.toString();
  privatekey = require("crypto").SHA1(seed);
  console.log(privatekey);
  x = require("crypto").PointGen(privatekey);
  setAdvertising(x);
  seed2 += 1;
}

function blink(){
  digitalWrite(LED1, 1);
  setTimeout("digitalWrite(LED1, 0)", 2000);
}

//Initial seed 18104774802383602804
//Use two pieces because we want a big seed that can be
//incremented, but Espruino only has 32 bit ints

//Change seed to a random value before running on Puck

seed1 = "1810477480";
seed2 = 2383602804;

setWatch(blink, BTN1, {repeat: true, edge: "rising"});
setTimeout(rotateKey, 10000);
setInterval(rotateKey, 900000);