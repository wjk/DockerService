import Foundation
import Collaboration
import SwiftCLI
import CommandLineExtensions
import os.log

class StartMachineCommand: Command {
	let name = "start-machine"
	let shortDescription = "Starts a docker-machine VM"

	let machineId = Parameter()

	func execute() throws {
		if getuid() != 0 {
			throw Exception.notRunningAsRoot
		}

		let logHandle = FileHandle(forAppendingAtPath: "/Library/Logs/docker-machine-launcher.log")

		let confFileURL = URL(fileURLWithPath: "/Library/Preferences/me.sunsol.docker-machine-launcher.machines.plist")
		let data = try MachineConfig.load(configurationFile: confFileURL)

		guard let machineConfig = data[machineId.value] else {
			throw Exception.machineNotFound(machineId: machineId.value)
		}

		let log = OSLog(subsystem: "me.sunsol.docker-machine-launcher", category: "StartMachine")

		guard machineConfig.enabled else {
			os_log(.default, log: log, "Machine %{public}@ marked as disabled, not starting", machineConfig.displayName)
			return
		}

		os_log(.default, log: log, "Starting %{public}@", machineConfig.displayName)

		guard let user = CBIdentity(name: machineConfig.userName, authority: .default()) as? CBUserIdentity else {
			os_log(.error, log: log, "Could not resolve user name %{public}@", machineConfig.userName)
			exit(1)
		}

		guard let homeDir = FileManager.default.homeDirectory(forUser: user.posixName) else {
			os_log(.error, log: log, "Could not resolve home directory for user %{public}@", machineConfig.userName)
			exit(1)
		}

		setuid(user.posixUID)
		if let workdir = machineConfig.workingDirectory {
			CommandLine.workingDirectory = URL(fileURLWithPath: workdir)
		} else {
			CommandLine.workingDirectory = homeDir
		}

		CommandLine.environment["HOME"] = homeDir.path
		CommandLine.environment["USER"] = user.posixName
		CommandLine.environment["PWD"] = CommandLine.workingDirectory.path

		let argv0URL = URL(fileURLWithPath: CommandLine.arguments[0])
		let dockerMachineCommandURL = argv0URL.deletingLastPathComponent().deletingLastPathComponent()
			.appendingPathComponent("Public").appendingPathComponent("docker-machine")

		guard var path = CommandLine.environment["PATH"] else {
			fatalError("PATH environment variable doesn't exist, this can't happen")
		}

		path = path + ":" + dockerMachineCommandURL.deletingLastPathComponent().path
		CommandLine.environment["PATH"] = path

		let stream = WriteStream.for(fileHandle: logHandle)
		let task = Task(executable: dockerMachineCommandURL.path, arguments: [ "start", machineConfig.machineName ], stdout: stream, stderr: stream)

		logHandle.write("Starting machine \(machineConfig.displayName)...")
		let exitCode = task.runSync()
		if exitCode == 0 {
			logHandle.write("Machine \(machineConfig.displayName) running")
		} else {
			os_log(.error, log: log, "Could not start machine %{public}@", machineConfig.displayName)
			exit(1)
		}
	}
}
