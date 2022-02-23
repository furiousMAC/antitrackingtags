//
//  SPDX-License-Identifier: AGPL-3.0-only
//

// Extension to OpenHaystack that allows for easy command line access to key creation and report retrieval
// Credit to Secure Mobile Networking Lab and OpenHaystack project for most of this, just pulling it out into a command line format

import Foundation
import Darwin
import Crypto
import CommonCrypto
import CNIOBoringSSL

var output = ""

func batchgen(num : Int, advFile : String, keyFile : String){
    var advString = ""
    
    //Make list of accessories
    var accessories = [Accessory]()
    for i in 1...num {
        print("Creating accessory " + String(i))
        do{
            let x = try Accessory(name: String(i))
            accessories.append(x)
        }
        catch{
            print("Error creating new accessory")
        }
    }
    
    print("Retrieving advertising keys")
    //Build string to output all advertising keys
    for a in accessories{
        do{
            advString += try a.getAdvertisementKey().base64EncodedString()
            advString += "\n"
        }
        catch{
            print("Error encoding advertising key")
        }
    }
    
    print("Writing public keys to file")
    //Write advertising keys to file
    do{
        try advString.write(toFile: advFile, atomically: true, encoding: .utf8)
    }
    catch{
        print("Error writing to advertising file")
    }
    
    print("Writing private keys to file")
    //Write full key information (including private keys) to plist
    do{
        let plistdata = try PropertyListEncoder().encode(accessories)
        try plistdata.write(to: URL(fileURLWithPath: keyFile))
    }
    catch{
        print("Error writing key file")
    }
}

func fetchReports(for accessories: [Accessory], with token: Data, outFile: String, completion: @escaping (Result<[FindMyDevice], Error>) -> Void) {
    let findMyDevices = accessories.compactMap({ acc -> FindMyDevice? in
        do {
            return try acc.toFindMyDevice()
        } catch {
            print("Failed getting id for key %@", String(describing: error))
            return nil
        }
    })

    var devices = findMyDevices

    fetchReports(with: token,  outFile: outFile, mydevices: devices) { error in
            print("Finished fetching reports, running completion")
            completion(.success(devices))
        }
}

func decryptReports(completion: () -> Void, outFile: String, mydevices: [FindMyDevice]) {
    print("Decrypting reports")

    var devices = mydevices
    // Iterate over all devices
    for deviceIdx in 0..<devices.count {
        devices[deviceIdx].decryptedReports = []
        let device = devices[deviceIdx]

        // Map the keys in a dictionary for faster access
        guard let reports = device.reports else { continue }
        let keyMap = device.keys.reduce(into: [String: FindMyKey](), { $0[$1.hashedKey.base64EncodedString()] = $1 })

        let accessQueue = DispatchQueue(label: "threadSafeAccess", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
        var decryptedReports = [FindMyLocationReport](repeating: FindMyLocationReport(lat: 0, lng: 0, acc: 0, dP: Date(), t: Date(), c: 0), count: reports.count)
        DispatchQueue.concurrentPerform(iterations: reports.count) { (reportIdx) in
            let report = reports[reportIdx]
            guard let key = keyMap[report.id] else { return }
            do {
                // Decrypt the report
                let locationReport = try DecryptReports.decrypt(report: report, with: key)
                accessQueue.async(flags: .barrier) {
                    decryptedReports[reportIdx] = locationReport
                }
            } catch {
                return
            }
        }

        accessQueue.sync {
            devices[deviceIdx].decryptedReports = decryptedReports
            output += "Tag ID:" + devices[deviceIdx].deviceId + "\n"
            
            for report in decryptedReports {
                output += String(describing: report.location) + "\n"
                output += String(describing: report.datePublished) + "\n"
                output += String(describing: report.timestamp) + "\n"
                output += String(describing: report.accuracy) + "\n"
                output += String(describing: report.confidence) + "\n"q
            }
            output += "\n"
        }
    }

    completion()

}

func fetchReports(with searchPartyToken: Data, outFile: String, mydevices: [FindMyDevice], completion: @escaping (Result<[FindMyDevice], Error>) -> Void) {

    DispatchQueue.global(qos: .background).async {
        let fetchReportGroup = DispatchGroup()

        let fetcher = ReportsFetcher()
        
        var devices = mydevices

        for deviceIndex in 0..<devices.count {
            fetchReportGroup.enter()
            devices[deviceIndex].reports = []

            // Only use the newest keys for testing
            let keys = devices[deviceIndex].keys

            let keyHashes = keys.map({ $0.hashedKey.base64EncodedString() })

            // 21 days
            let duration: Double = (24 * 60 * 60) * 21
            let startDate = Date() - duration

            fetcher.query(forHashes: keyHashes, start: startDate, duration: duration, searchPartyToken: searchPartyToken) { jd in
                guard let jsonData = jd else {
                    fetchReportGroup.leave()
                    return
                }

                do {
                    // Decode the report
                    let report = try JSONDecoder().decode(FindMyReportResults.self, from: jsonData)
                    devices[deviceIndex].reports = report.results

                } catch {
                    print("Failed with error \(error)")
                    devices[deviceIndex].reports = []
                }
                fetchReportGroup.leave()
            }

        }

        // Completion Handler
        fetchReportGroup.notify(queue: .main) {
            print("Finished loading the reports. Now decrypt them")

            // Export the reports to the desktop
            var reports = [FindMyReport]()
            for device in devices {
                for report in device.reports! {
                    reports.append(report)
                }
            }

            #if EXPORT
                if let encoded = try? JSONEncoder().encode(reports) {
                    let outputDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                    try? encoded.write(to: outputDirectory.appendingPathComponent("reports.json"))
                }
            #endif

            DispatchQueue.main.async {
                decryptReports(completion: { () in completion(.success(devices))}, outFile: outFile, mydevices: devices)

            }
        }
    }

}

func batchfetch(keyFile: String, outFile: String){
    var accessories = [Accessory]()
    do{
        print("Loading plist file")
        let accData = try Data(contentsOf: URL(fileURLWithPath: keyFile))
        accessories = try PropertyListDecoder().decode([Accessory].self, from: accData)
    }
    catch{
        print("Error loading accessory key file")
    }
    
    fetchAccessories(accessories: accessories, outFile: outFile)
}

func fetchAccessories(accessories: [Accessory], outFile: String){
    
    print("Retrieving anisette data")
    
    AnisetteDataManager.shared.requestAnisetteData { result in
        switch result {
        case .failure(_):
            print("Could not retrieve anisette data")
            return
        case .success(let accountData):
            print("Getting search party token")
            guard let token = accountData.searchPartyToken,
                token.isEmpty == false
            else {
                print("Could not retrieve search party token")
                return
            }
            print("Fetching reports")
            fetchReports(for: accessories, with: token, outFile: outFile) { result in
                switch result {
                case .failure(let error):
                    print("Downloading reports failed %@", error.localizedDescription)
                    return
                case .success(let devices):

                    print("Writing reports to file")

                    do{
                        try output.write(toFile: outFile, atomically: true, encoding: .utf8)
                    }
                    catch{
                        print("Error writing to output file")
                    }
                    print("Reports completed")
                }
            }
        }
    }
}



func ecfetch(seed: String, startday: UInt64, numdays: Int, outFile: String){
    var intseed = UInt64(seed)!
    
    let keysperday = UInt64(100)
    
    intseed += startday * keysperday
    
    let group = CNIOBoringSSL_EC_GROUP_new_by_curve_name(NID_secp224r1)

    let ctx = CNIOBoringSSL.CNIOBoringSSL_BN_CTX_new()
    
    var accessories = [Accessory]()
    
    for s in intseed...intseed+(UInt64(numdays)*keysperday) {
        var hb = [UInt8](repeating: 0, count: Crypto.Insecure.SHA1Digest.byteCount)
        
        
        //let b = CNIOBoringSSL.CNIOBoringSSL_BN_new()
        
        CommonCrypto.CC_SHA1(Array(String(s).utf8), CC_LONG(String(s).count), &hb)
        print("Seed " + String(s) + "--------")
        print("Hash")
        print(hb)
        
        let b = CNIOBoringSSL_BN_new()
        CNIOBoringSSL_BN_bin2bn(&hb, hb.count, b)
        
        print("Private key")
        CNIOBoringSSL_BN_print_fp(stdout, b)
        print()
        
        let pt = CNIOBoringSSL_EC_POINT_new(group)
        CNIOBoringSSL_EC_POINT_mul(group, pt, b, nil, nil, ctx)
        
        let x = CNIOBoringSSL_BN_new()
        CNIOBoringSSL_EC_POINT_get_affine_coordinates(group, pt, x, nil, ctx)
        
        var ob = [UInt8](repeating: 0, count: 20)
        //let ob = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)
        
        CNIOBoringSSL_BN_bn2bin(b, &ob)
        //let oba = Array(UnsafeBufferPointer(start: ob, count: 16))
        print("Public key X coord")
        print(ob)
        
        let xdat = NSData(bytes: ob, length: 20)
        
        do{
            let a = try Accessory(name: String(s), key: xdat as Data)
            accessories.append(a)
        }
        catch{
            print("Error creating accessory " + String(s))
        }
        CNIOBoringSSL_EC_POINT_free(pt)
        CNIOBoringSSL_BN_free(b)
        CNIOBoringSSL_BN_free(x)
    }
    
    fetchAccessories(accessories: accessories, outFile: outFile)
}

let args = CommandLine.arguments

if( args.count < 2 ){
    print("Actions:")
    print("batchgen <num> <advertising output file> <key export file>")
    print("\tCreates <num> keys, stores the advertising keys in one file and the private keys in another")
    print("batchfetch <private key file> <output file>")
    print("ecfetch <seed number> <starting day> <# days> <output file>")
    print("\tRetrieves reports for hash-generated EC keys starting with <seed number>")
    print("\t<starting day> is the offset from day 0 to start retrieving keys")
    print("Example: batchfetch 12345678 0 5 out.txt")
    print("Retrieves location reports for first 5 days with the seed 123455678")
}

if( args[1] == "batchgen" ){
    let batchsize = Int(args[2]) ?? 0
    print("Creating keys")
    print(batchsize)
    batchgen(num : batchsize, advFile : args[3], keyFile: args[4])
    print("Done generating keys")
}

if( args[1] == "batchfetch" ){
    print("Batch fetching from plist...")
    batchfetch(keyFile: args[2], outFile: args[3])
}

if( args[1] == "ecfetch"){
    if( args.count != 6) {
        print("Incorrect number of args")
        exit(0)
    }
    ecfetch(seed: args[2], startday: UInt64(args[3]) ?? 0, numdays: Int(args[4]) ?? 5, outFile: args[5])
}

RunLoop.main.run()
