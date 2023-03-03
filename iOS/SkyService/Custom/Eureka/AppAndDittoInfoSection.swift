import Eureka
import DittoSwift

func appAndDittoInfoSection() -> Section {
    let ditto = DataService.shared.ditto!
    let sdkVersion = ditto.sdkVersion
    let versions = sdkVersion.dropFirst(4).split(separator: "_")
    let semVer = String(versions[0])
    let commitHash = String(versions[1])
    return Section("App Info")
        <<< LabelRow("appVersionAndBuild") { row in
            row.title = "App version and build"
            guard let v = Bundle.main.releaseVersionNumber, let b = Bundle.main.buildVersionNumber else { return }
            row.value = "Version: \(v) Build: \(b)"
        }
        <<< LabelRow("platform") { row in
            row.title = "iOS: "
            row.value = UIDevice.current.systemVersion
        }
        <<< LabelRow("dittoSemver") { row in
            row.title = "Ditto version: "
            row.value = "\(String(semVer))#\(String(commitHash))"
        }
}
