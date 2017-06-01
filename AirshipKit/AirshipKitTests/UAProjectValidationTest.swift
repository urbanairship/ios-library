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
    
    func validateProjectForTarget(buildTarget : String, buildOS : String) {
        print("Validating files included in " + buildTarget + " for " + buildOS + " build.")
        
        // get all of the files from the xcode project file for this target
        var filesFromProjectWithOptionals : Array<URL?> = []
        
        for target in xcodeProject!.project.targets {
            if (target.name != buildTarget) {
                continue
            }
            for buildPhase in target.buildPhases {
                if ((type(of:buildPhase) == XcodeEdit.PBXSourcesBuildPhase)
                    || (type(of:buildPhase) == XcodeEdit.PBXHeadersBuildPhase)) {
                    filesFromProjectWithOptionals += buildPhase.files.map {
                        return ($0.fileRef as? PBXFileReference)?.fullPath.url(with:convertSourceTreeFolderToURL)
                    }
                }
            }
        }
        
        let filesFromProject : Array<URL> = filesFromProjectWithOptionals.flatMap{ $0 }
        
        // get all of the URLs files from the directories for this target
        var filesFromDirectory : Array<URL> = []
        let fileManager = FileManager.default
        let subDirectoriesToInclude = ["common", buildOS]
        fileManager.enumerator(atPath:sourceRootURL!.path)?.forEach({ (e) in
            if let e = e as? String, let url = URL(string: e) {
                // ignore .DS_Store
                if (e.contains(".DS_Store")) {
                    return
                }

                let thisSubDirectory = url.deletingLastPathComponent().lastPathComponent
                if (subDirectoriesToInclude.contains(thisSubDirectory)) {
                    filesFromDirectory.append(sourceRootURL!.appendingPathComponent(e))
                }

            }
        })
        
        let filesFromProjectAsSet = Set(filesFromProject.map { $0.absoluteURL } )
        let filesFromDirectoryAsSet = Set(filesFromDirectory.map { $0.absoluteURL } )
        
        if (filesFromProjectAsSet == filesFromDirectoryAsSet) {
            print("Project and project directory match")
        } else {
            print("Project and project directory do not match")
            let filesMissingFromDirectory = filesFromProjectAsSet.subtracting(filesFromDirectoryAsSet)
            print(filesMissingFromDirectory.count, " files missing from the directories")
            for file in filesMissingFromDirectory {
                print(file.path + " is not in directory")
            }
            let filesMissingFromProject = filesFromDirectoryAsSet.subtracting(filesFromProjectAsSet)
            print(filesMissingFromProject.count, " files missing from the project")
            for file in filesMissingFromProject {
                print(file.path + " is not in project")
            }
            XCTFail("Project and project directory do not match")
        }
    }

    func testAirshipKitTvOS() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        validateProjectForTarget(buildTarget: "AirshipKit tvOS", buildOS: "tvos")
    }


    func testAirshipKit() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        validateProjectForTarget(buildTarget: "AirshipKit", buildOS: "ios")
    }
    
    func testAirshipLib() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        validateProjectForTarget(buildTarget: "AirshipLib", buildOS: "ios")
    }
    
}
