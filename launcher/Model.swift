import Foundation

internal enum Exception: Error {
	case notRunningAsRoot
	case commandFailure
	case message(text: String)

	var localizedDescription: String {
		get {
			switch self {
			case .notRunningAsRoot:
				return "This command must be run as root"
			case .commandFailure:
				return "External command failure, check docker-machine-launcher.log for details"
			case .message(let text):
				return text
			}
		}
	}
}

internal final class MachineConfig: Codable {
	internal var displayName: String = ""
	internal var vmService: String = "xhyve"
	internal var userName: String = ""
	internal var workingDirectory: String?
	internal var machineName: String = "default"
	internal var enabled: Bool = true

	// MARK: Coding

	internal class func load(configurationFile confFile: URL) throws -> [String: MachineConfig] {
		let data = try Data(contentsOf: confFile)

		let decoder = PropertyListDecoder()
		return try decoder.decode([String: MachineConfig].self, from: data)
	}

	internal enum CodingKeys: String, CodingKey {
		case displayName = "display_name"
		case vmService = "vmservice"
		case userName = "user"
		case workingDirectory = "workdir"
		case machineName = "machine_name"
		case enabled = "enabled"
	}
}
