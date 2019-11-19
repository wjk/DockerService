import Foundation
import SwiftCLI
import CommandLineExtensions
import os.log

internal class CreateMachineCommand: Command {
	let name = "setup"
	let shortDescription = "Creates (if necessary) and starts the Docker virtual machine."

	internal static func createRequiredDirectories() throws {
		guard getuid() == 0 else {
			throw Exception.notRunningAsRoot
		}

		let log = OSLog(subsystem: "me.sunsol.docker-machine-launcher", category: "Setup")
		let fm = FileManager.default

		if !fm.directoryExists(atPath: "/Library/ServiceData/Docker/docker-machine") {
			os_log(.default, log: log, "/Library/ServiceData/Docker/docker-machine does not exist, creating it")
			try fm.createDirectory(atPath: "/Library/ServiceData/Docker/docker-machine", withIntermediateDirectories: true, attributes: nil)

			let attributes: [FileAttributeKey: Any] = [
				FileAttributeKey.ownerAccountName: "daemon",
				FileAttributeKey.posixPermissions: 0o755
			]
			try fm.setAttributes(attributes, ofItemAtPath: "/Library/ServiceData/Docker/docker-machine")
		}

		if !fm.directoryExists(atPath: "/Library/ServiceData/Docker/Shared") {
			os_log(.default, log: log, "/Library/ServiceData/Docker/Shared does not exist, creating it")
			try fm.createDirectory(atPath: "/Library/ServiceData/Docker/Shared", withIntermediateDirectories: true, attributes: nil)

			let attributes: [FileAttributeKey: Any] = [
				FileAttributeKey.ownerAccountName: "daemon",
				FileAttributeKey.groupOwnerAccountName: "staff",
				FileAttributeKey.posixPermissions: 0o775
			]
			try fm.setAttributes(attributes, ofItemAtPath: "/Library/ServiceData/Docker/Shared")
		}
	}

	internal static func runDockerMachineCreate(logHandle: FileHandle) throws {
		let log = OSLog(subsystem: "me.sunsol.docker-machine-launcher", category: "CreateMachine")

		let fm = FileManager.default
		let argv0URL = URL(fileURLWithPath: CommandLine.arguments[0])
		let dockerMachineCommandURL = argv0URL.deletingLastPathComponent().deletingLastPathComponent()
			.appendingPathComponent("Public").appendingPathComponent("docker-machine")

		guard var path = CommandLine.environment["PATH"] else {
			fatalError("PATH environment variable doesn't exist, this can't happen")
		}

		path = path + ":" + dockerMachineCommandURL.deletingLastPathComponent().path
		CommandLine.environment["PATH"] = path

		if !fm.directoryExists(atPath: "/Library/ServiceData/Docker/docker-machine/machines/default") {
			os_log(.default, log: log, "Default Docker machine does not exist, creating it...")

			let argv = [
				"--storage-path", "/Library/ServiceData/Docker/docker-machine",
				"create", "-d", "xhyve", "--xhyve-uuid", "44A05926-6238-43F6-99F2-522951DADF92",
				"--xhyve-virtio-9p", "/Library/ServiceData/Docker/Shared",
				"default"
			]

			let stream = WriteStream.for(fileHandle: logHandle)
			let creationTask = Task(executable: dockerMachineCommandURL.path, arguments: argv,
									stdout: stream, stderr: stream)
			let exitCode = creationTask.runSync()

			guard exitCode == 0 else {
				throw Exception.message(text: "docker-machine create failed")
			}
		}
	}

	func execute() throws {
		guard getuid() == 0 else {
			throw Exception.notRunningAsRoot
		}

		let logHandle = FileHandle(forAppendingAtPath: "/Library/Logs/docker-machine-launcher.log")

		try CreateMachineCommand.createRequiredDirectories()

		// docker-machine create leaves the VM running after it is done
		try CreateMachineCommand.runDockerMachineCreate(logHandle: logHandle)
		waitForSigterm(logHandle: logHandle)
	}
}
