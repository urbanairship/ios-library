/* Copyright 2017 Urban Airship and Contributors */

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
        xcodeProject = try! XCProjectFile(xcodeprojURL: xcodeprojPath)
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

    func validateProjectForTarget(buildTarget : String, buildOS : String, targetSubFolder : String? = nil) {
        print("Validating files included in " + buildTarget + " for " + buildOS + " build.")

        // get all of the files from the xcode project file for this target
        var filesFromProjectWithOptionals : Array<URL?> = []

        for target in xcodeProject!.project.targets {
            print(target.name)
            if (target.name != buildTarget) {
                continue
            }
            for buildPhase in target.buildPhases {
                if ((type(of:buildPhase) == XcodeEdit.PBXSourcesBuildPhase)
                    || (type(of:buildPhase) == XcodeEdit.PBXHeadersBuildPhase)) {

                    filesFromProjectWithOptionals += buildPhase.files.map {
                        return ($0.fileRef as? PBXFileReference)?.fullPath.url(with:convertSourceTreeFolderToURL)
                    }
                    print("filesFromProjectWithOptionals.count = \(filesFromProjectWithOptionals.count)")
                }
            }
        }

        let filesFromProject : Array<URL> = filesFromProjectWithOptionals.flatMap{ $0 }
        
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

        let filesFromProjectAsSet = Set(filesFromProject.map { $0.absoluteURL } )
        let filesFromFoldersesAsSet = Set(filesFromDirectories.map { $0.absoluteURL } )

        if (filesFromProjectAsSet == filesFromFoldersesAsSet) {
            print("Project and project folders match")
        } else {
            print("Project and project folders do not match")
            print("\(filesFromProjectAsSet.count) files in the project")
            for file in filesFromProjectAsSet {
                print(file.path + " is in the project")
            }
            let filesMissingFromFolders = filesFromProjectAsSet.subtracting(filesFromFoldersesAsSet)
            print(filesMissingFromFolders.count, " files missing from the folders")
            for file in filesMissingFromFolders {
                print(file.path + " is not in the folders")
            }
            print("\(filesFromFoldersesAsSet.count) files in the folders")
            for file in filesFromFoldersesAsSet {
                print(file.path + " is in the folders")
            }
            let filesMissingFromProject = filesFromFoldersesAsSet.subtracting(filesFromProjectAsSet)
            print(filesMissingFromProject.count, " files missing from the project")
            for file in filesMissingFromProject {
                print(file.path + " is not in project")
            }
            XCTFail("Project and project folders do not match")
        }
    }

    func testAirshipKit() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        validateProjectForTarget(buildTarget: "AirshipKit", buildOS: "ios")
    }

    func testAirshipKitTvOS() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        validateProjectForTarget(buildTarget: "AirshipKit tvOS", buildOS: "tvos", targetSubFolder: "AirshipKit")
    }

    func testAirshipLib() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        validateProjectForTarget(buildTarget: "AirshipLib", buildOS: "ios", targetSubFolder: "AirshipKit")
    }
    
}
