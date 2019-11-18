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
	public func write(_ string: String) {
		self.write(string.data(using: .utf8)!)
	}
}

// MARK: -

func createLogHandle(forPath path: String) -> FileHandle {
	let fd = open(path, O_CREAT | O_WRONLY | O_APPEND, 0o644)
	assert(fd != -1, "open(\(path)) failed with errno=\(errno)")

	let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
	handle.write("\n--- docker-machine service restarted ---\n")
	return handle
}

func main() {
	let logger = OSLog(subsystem: "me.sunsol.docker-machine-launcher", category: "")
	let logPath = "/Library/Logs/docker-machine.log"

	if getuid() != 0 {
		logger.log(type: .error, "docker-machine-launcher must be run as root")
		print("error: docker-machine-launcher must be run as root", to: &CommandLine.standardError)
		exit(1)
	}

	let logHandle = createLogHandle(forPath: logPath)
	setuid(1) // drop privileges, uid_t 1 == daemon user

	let myURL = URL(fileURLWithPath: CommandLine.arguments[0])
	let executableURL = myURL.deletingLastPathComponent().appendingPathComponent("Prefix")
		.appendingPathComponent("bin").appendingPathComponent("docker-machine")

	let machineDirectoryURL = URL(fileURLWithPath: "/Library/ServiceData/docker-machine/machines/default")
	if !FileManager.default.directoryExists(atPath: machineDirectoryURL.path) {
		logHandle.write("*** 'default' machine does not exist, running docker-machine create")
		logger.log(type: .default, "'default' machine does not exist, running docker-machine create...")

		let argv = [
			"--storage-path", "/Library/ServiceData/docker-machine",
			"create", "-d", "xhyve", "--xhyve-uuid", "44A05926-6238-43F6-99F2-522951DADF92", "default"
		]

		let stream = WriteStream.for(fileHandle: logHandle)
		let task = Task(executable: executableURL.path, arguments: argv, stdout: stream, stderr: stream)
		let exitCode = task.runSync()

		if exitCode != 0 {
			logger.log(type: .error, "docker-machine create failed, check %{public}@ for details", logPath)
			sleep(10) // to prevent launchd from restarting us
			exit(1)
		}

		logHandle.write("*** docker-machine create succeeded")
		logger.log(type: .default, "docker-machine create succeeded")
	}

	let startArgv = [
		"--storage-path", "/Library/ServiceData/docker-machine",
		"start", "default"
	]

	logger.log(type: .default, "About to call docker-machine start...")

	let stream = WriteStream.for(fileHandle: logHandle)
	let startTask = Task(executable: executableURL.path, arguments: startArgv, stdout: stream, stderr: stream)
	let exitCode = startTask.runSync()
	if exitCode != 0 {
		logger.log(type: .error, "docker-machine start failed, check %{public}@ for details", logPath)
		sleep(10) // to prevent launchd from restarting us
		exit(1)
	}

	let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM)
	sigtermSource.setEventHandler {
		logger.log(type: .default, "Calling docker-machine stop...")

		let stopArgv = [
			"--storage-path", "/Library/ServiceData/docker-machine",
			"stop", "default"
		]

		let stopTask = Task(executable: executableURL.path, arguments: stopArgv, stdout: stream, stderr: stream)
		stopTask.runAsync()
		exit(0)
	}

	sigtermSource.activate()
	signal(SIGTERM, SIG_IGN)
	dispatchMain()
}

main()
