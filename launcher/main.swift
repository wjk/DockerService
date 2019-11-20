import Foundation
import CommandLineExtensions
import SwiftCLI
import os.log

extension FileHandle: TextOutputStream {
	public convenience init(forAppendingAtPath path: String, truncate: Bool = false) {
		var flags = O_CREAT | O_WRONLY | O_APPEND
		if truncate {
			flags |= O_TRUNC
		}

		let fd = open(path, flags, 0o644)
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
		os_log(.default, log: log, "Calling docker-machine stop...")

		let argv0URL = URL(fileURLWithPath: CommandLine.arguments[0])
		let dockerMachineCommandURL = argv0URL.deletingLastPathComponent().deletingLastPathComponent()
			.appendingPathComponent("Public").appendingPathComponent("docker-machine")

		let stopArgv = [
			"--storage-path", "/Library/ServiceData/Docker/docker-machine",
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

// MARK: -

class DaemonHelpMessageGenerator: HelpMessageGenerator {
	func writeUnrecognizedErrorMessage(for error: Error, to out: WritableStream) {
		let message: String

		// For some reason, this doesn't happen automatically.
		// I must manually cast to get the correct description out.
		if let exc = error as? Exception {
			message = exc.localizedDescription
		} else {
			message = error.localizedDescription
		}

		let log = OSLog(subsystem: "me.sunsol.docker-machine-launcher", category: "")
		os_log(.error, log: log, "Unhandled error: %{public}@", message)

		out.print("unhandled error: \(message)")
		exit(1)
	}
}

func main() {
	let logFile = FileHandle(forAppendingAtPath: "/Library/Logs/docker-machine-launcher.log", truncate: true)
	logFile.write("-- docker-machine-launcher restarted--\n\n");

	let handler = CLI(name: "docker-machine-launcher")
	handler.helpMessageGenerator = DaemonHelpMessageGenerator()
	handler.commands = [CreateMachineCommand(), RunDaemonCommand()]
	handler.goAndExit()
}

main()
