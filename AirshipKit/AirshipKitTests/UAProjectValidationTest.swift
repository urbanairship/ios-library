/* Copyright Airship and Contributors */

import XCTest
import XcodeEdit

class UAProjectValidationTest: XCTestCase {

    var sourceRootURL : URL?
    var xcodeProject : XCProjectFile?

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let infoPlistDict = NSDictionary(contentsOfFile: Bundle(for: type(of: self)).path(forResource: "Info", ofType: "plist")!) as! [String: AnyObject]
        // The xcodeproj file to load
        let projectFilePath = infoPlistDict["PROJECT_FILE_PATH"] as! String
        let xcodeprojPath = URL(fileURLWithPath: projectFilePath)

        // Load from the xcodeproj file
        do {
            xcodeProject = try XCProjectFile(xcodeprojURL: xcodeprojPath)
        } catch let error {
            XCTFail("Unable to load xcodeproj file - \(String(describing:error))")
            return
        }
        XCTAssert(xcodeProject != nil,"Unable to load xcodeproj file - something wrong with the plist?")

        // path to the source root
        sourceRootURL = xcodeprojPath.deletingLastPathComponent()
        XCTAssert(sourceRootURL != nil)

        // AirshipLib.h is created by the ios and tvos builds. In case one wasn't built, create AirshipLib.h here
        let fileManager = FileManager.default
        let airshipKitURL = sourceRootURL?.appendingPathComponent("AirshipKit")

        let iosAirshipLibURL = airshipKitURL?.appendingPathComponent("ios/AirshipLib.h")
        XCTAssert(iosAirshipLibURL != nil)
        if (!fileManager.fileExists(atPath:(iosAirshipLibURL?.path)!)) {
            try? "".write(to: iosAirshipLibURL!, atomically: false, encoding: String.Encoding.utf8)
        }

        let tvosAirshipLibURL = airshipKitURL?.appendingPathComponent("tvos/AirshipLib.h")
        XCTAssert(tvosAirshipLibURL != nil)
        if (!fileManager.fileExists(atPath:(tvosAirshipLibURL?.path)!)) {
            try? "".write(to: tvosAirshipLibURL!, atomically: false, encoding: String.Encoding.utf8)
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func convertSourceTreeFolderToURL(sourceTreeFolder: SourceTreeFolder) -> URL {
        if (sourceTreeFolder != .sourceRoot) {
            XCTFail("SourceTreeFolders other than .sourceRoot are not currently supported by this tool")
        }
        return sourceRootURL!
    }

    func getFilesSet(buildTarget : String) -> Array<URL> {
        if (xcodeProject == nil) {
            return []
        }
        // get all of the files from the xcode project file for this target
        var filesFromProjectWithOptionals : Array<URL?> = []

        for target in xcodeProject!.project.targets {
            if (target.value?.name != buildTarget) {
                continue
            }
            for buildPhaseReference : Reference<PBXBuildPhase> in (target.value?.buildPhases)! {
                if let buildPhase : PBXBuildPhase = buildPhaseReference.value {
                    if ((type(of:buildPhase) == XcodeEdit.PBXSourcesBuildPhase.self)
                        || (type(of:buildPhase) == XcodeEdit.PBXHeadersBuildPhase.self)) {
                        
                        filesFromProjectWithOptionals += buildPhase.files.map {
                            if let buildFile : PBXBuildFile = $0.value {
                                return (buildFile.fileRef?.value as? PBXFileReference)?.fullPath?.url(with:convertSourceTreeFolderToURL)
                            } else {
                                return URL(string:"")
                            }
                        }
                    }
                }
            }
        }

        return filesFromProjectWithOptionals.compactMap{ $0 } as Array<URL>
    }

    func validateProjectForTarget(buildTarget : String, buildOS : String, targetSubFolder : String? = nil) {
        let filesFromTarget : Array<URL> = getFilesSet(buildTarget: buildTarget)
        if (filesFromTarget.count == 0) {
            return
        }
        
        // get all of the URLs files from the directories for this target
        var filesFromDirectories : Array<URL> = []
        let fileManager = FileManager.default
        let targetSubFolder : String = (targetSubFolder == nil) ? buildTarget : targetSubFolder!
        let targetRootURL = sourceRootURL?.appendingPathComponent(targetSubFolder)
        let subDirectoriesToInclude = ["common", buildOS]
        fileManager.enumerator(atPath:targetRootURL!.path)?.forEach({ (e) in
            if let e = e as? String, let url = URL(string: e) {
                // ignore .DS_Store
                if (e.contains(".DS_Store")) {
                    return
                }

                // ignore .keepme
                if (e.contains(".keepme")) {
                    return
                }

                let thisSubDirectory = url.deletingLastPathComponent().lastPathComponent
                if (subDirectoriesToInclude.contains(thisSubDirectory)) {
                    filesFromDirectories.append(targetRootURL!.appendingPathComponent(e))
                }

            }
        })

        let filesFromTargetAsSet = Set(filesFromTarget.map { $0.absoluteURL } )
        let filesFromFoldersesAsSet = Set(filesFromDirectories.map { $0.absoluteURL } )

        if (filesFromTargetAsSet != filesFromFoldersesAsSet) {
            let filesMissingFromFolders = filesFromTargetAsSet.subtracting(filesFromFoldersesAsSet)
            if (filesMissingFromFolders.count > 0) {
                print(filesMissingFromFolders.count, " files missing from the folders")
            }
            for file in filesMissingFromFolders {
                print(file.path + " is not in the folders")
            }
            let filesMissingFromTarget = filesFromFoldersesAsSet.subtracting(filesFromTargetAsSet)
            if (filesMissingFromTarget.count > 0) {
                print(filesMissingFromTarget.count, " files missing from the target:",buildTarget)
            }
            for file in filesMissingFromTarget {
                print(file.path + " is not in target:", buildTarget)
            }
            XCTFail("Project and project folders do not match")
        }
    }

    // Validates that each framework import corresponds to an import in UAirship.h
    func validateUAirshipHeader(buildTarget : String) {
        let filesFromProject : Array<URL> = getFilesSet(buildTarget: buildTarget)
        if (filesFromProject.count == 0) {
            return
        }

        // Holds the string contents of UAirship.h
        var airshipHeaderContents:String?

        // Pattern matches framework imports only
        guard let importRegex = try? NSRegularExpression(pattern: "#import <\\w+\\/\\w+\\.h>") else { return }

        var importMatches : Array<String> = []

        // Regex matching helper
        let matches = {(text: String) -> [String] in
                let regex = importRegex
                let nsText = text as NSString
                let results = regex.matches(in: text, range: NSRange(location: 0, length:nsText.length))
                return results.map { nsText.substring(with: $0.range)}
        }

        for file in filesFromProject {
            guard let fileContents = try? String(contentsOf: file) else {
                print("Unable to parse file contents into string.")
                continue
            }

            if (file.lastPathComponent == "UAirship.h") {
                airshipHeaderContents = fileContents
                continue
            }

            importMatches = importMatches + matches(fileContents)
        }

        // Remove duplicates
        let importSet = Set(importMatches)

        if (airshipHeaderContents == nil) {
            print("UAirship.h is missing from the project files set.")
            XCTAssert(false)
            return
        }

        for importString in importSet {
            // Ignore these imports
            switch importString {
                case "#import <UIKit/UIKit.h>":
                    continue
                case "#import <CommonCrypto/CommonDigest.h>":
                    continue
                case "#import <objc/runtime.h>":
                    continue
                case "#import <Foundation/Foundation.h>":
                    continue
                case "#import <SystemConfiguration/SCNetworkReachability.h>":
                    continue

                default:
                    XCTAssert(airshipHeaderContents!.contains(importString), "UAirship header does not contain \(importString).")
            }
        }
    }

    func testAirshipKit() {
        validateProjectForTarget(buildTarget: "AirshipKit", buildOS: "ios")
    }

    func testAirshipKitTvOS() {
        validateProjectForTarget(buildTarget: "AirshipKit tvOS", buildOS: "tvos", targetSubFolder: "AirshipKit")
    }

    func testAirshipLib() {
        validateProjectForTarget(buildTarget: "AirshipLib", buildOS: "ios", targetSubFolder: "AirshipKit")

        // Validate that each framework import is represented in the UAirship header
        validateUAirshipHeader(buildTarget: "AirshipLib")
    }
}
