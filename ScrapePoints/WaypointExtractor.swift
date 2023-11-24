//
//  WaypointExtractor.swift
//  ScrapePoints
//
//  Created by Steven Duzevich on 17/11/2023.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct WaypointExtractor: View {
    @State private var URL = ""
    @State var showExporter = false
    @State var document: GPXDocument = GPXDocument()
    
    var body: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let first = strings.first else { return }
            URL = first
            justDoEverything(URL: URL)
        }
        .fileExporter(isPresented: $showExporter, document: document, contentType: UTType(filenameExtension: "gpx")!) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                print(error.localizedDescription)
            }
            showExporter = false
        }
    }
    
    func justDoEverything(URL: String) {
        var request = URLRequest(url: Foundation.URL(string: URL)!)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        let session = URLSession.init(configuration: URLSessionConfiguration.default)
        session.dataTask(with: request) {data,response,error in
            if let data = data {
                var contents = String(data: data, encoding: .utf8)!
//                contents = contents.replacingOccurrences(of: "\n", with: "")
//                contents = contents.replacingOccurrences(of: "\u{00a0}", with: " ")
                
                // isolate json location data
                let approxStart = contents.range(of: "window.APP_INITIALIZATION_STATE")
                let start = contents.index((approxStart?.upperBound)!, offsetBy: 1)
                let end = contents.range(of: ";window.APP_FLAGS", range: start..<contents.endIndex)?.lowerBound
                let range = start..<end!
                contents = String(contents[range]).replacingOccurrences(of: "')]}\'\n", with: "")
                                                
                // get location details from isolated contents
                var detailsJSON = try! JSONSerialization.jsonObject(with: contents.data(using: .utf8)!, options: []) as! NSArray
                detailsJSON = detailsJSON[3] as! NSArray
                let brokenJSON = (detailsJSON[2] as! String).dropFirst(5)
                detailsJSON = try! JSONSerialization.jsonObject(with: brokenJSON.data(using: .utf8)!, options: []) as! NSArray
                detailsJSON = detailsJSON[0] as! NSArray
                detailsJSON = detailsJSON[1] as! NSArray

                // isolate necessary location data
                var locationsData: [(String, String, String)] = []
                for location in detailsJSON {
                    let locationData = (location as! NSArray)[14] as! NSArray
                    let name = locationData[11] as! String
                    let latitude = String(describing: (locationData[9] as! NSArray)[2] as! NSNumber)
                    let longitude = String(describing: (locationData[9] as! NSArray)[3] as! NSNumber)
                    locationsData.append((name, latitude, longitude))
                }
                document.text = writeGPX(data: locationsData)
                print(writeGPX(data: locationsData))
                showExporter = true
            }
        }.resume()
    }
    
    func writeGPX(data: [(String, String, String)]) -> String {
        let xmlHeader = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        let gpxHeader = "<gpx xmlns=\"http://www.topografix.com/GPX/1/1\" version=\"1.1\" creator=\"GPX from Maps\">\n"
        let gpxFooter = "</gpx>\n"
        var gpxBody = ""
        for location in data {
            gpxBody += "\t<wpt lat=\"\(location.1)\" lon=\"\(location.2)\">\n"
            gpxBody += "\t\t<name>\(location.0)</name>\n"
            gpxBody += "\t</wpt>\n"
        }
        let gpx = xmlHeader + gpxHeader + gpxBody + gpxFooter
        return gpx
    }
}

struct GPXDocument: FileDocument {
    static var readableContentTypes = [UTType(filenameExtension: "gpx")!]

    var text = ""

    init(initialText: String = "") {
        text = initialText
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct WaypointExtractor_Previews: PreviewProvider {
    static var previews: some View {
        WaypointExtractor()
    }
}


