import Foundation
import CommandLineExtensions
import SwiftCLI
import os.log

extension OSLog {
	func log(type: OSLogType, _ message: StaticString, _ args: CVarArg...) {
		os_log(type, log: self, message, args)
	}
}

extension FileHandle: TextOutputStream {
	public convenience init(forAppendingAtPath path: String) {
		let fd = open(path, O_CREAT | O_WRONLY | O_APPEND, 0o644)
		assert(fd != -1, "open(\(path)) failed with errno=\(errno)")
		self.init(fileDescriptor: fd, closeOnDealloc: true)
	}

	public func write(_ string: String) {
		self.write(string.data(using: .utf8)!)
	}
}

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

// MARK: -

func waitForSigterm(logHandle: FileHandle) -> Never {
	let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM)
	sigtermSource.setEventHandler {
		let log = OSLog(subsystem: "me.sunsol.docker-machine-launcher", category: "Shutdown")
		log.log(type: .default, "Calling docker-machine stop...")

		let argv0URL = URL(fileURLWithPath: CommandLine.arguments[0])
		let dockerMachineCommandURL = argv0URL.deletingLastPathComponent()
			.appendingPathComponent("Public").appendingPathComponent("docker-machine")

		let stopArgv = [
			"--storage-path", "/Library/ServiceData/docker-machine",
			"stop", "default"
		]

		let stream = WriteStream.for(fileHandle: logHandle)
		let stopTask = Task(executable: dockerMachineCommandURL.path, arguments: stopArgv,
							stdout: stream, stderr: stream)
		stopTask.runAsync()
		exit(0)
	}

	sigtermSource.activate()
	signal(SIGTERM, SIG_IGN)
	dispatchMain()
}

func main() {
	let handler = CLI(name: "docker-machine-launcher")
	handler.commands = [CreateMachineCommand(), RunDaemonCommand()]
	_ = handler.go()
}

main()
