import Foundation
import SwiftCLI
import CommandLineExtensions
import os.log

internal class RunDaemonCommand: Command {
	let name = "run-daemon"
	let shortDescription = "Runs docker-machine. Inteded to be used with launchd."

	func execute() throws {
		let log = OSLog(subsystem: "me.sunsol.docker-machine-launcher", category: "Daemon")

		guard getuid() == 0 else {
			log.log(type: .error, "docker-machine-launcher must be run as root")
			print("error: This command must be run as root", to: &CommandLine.standardError)
			sleep(10) // stop launchd from restarting us in a loop
			exit(-1)
		}

		let logHandle = FileHandle(forAppendingAtPath: "/Library/Logs/docker-machine-launcher.log")

		let fm = FileManager.default
		let argv0URL = URL(fileURLWithPath: CommandLine.arguments[0])
		let dockerMachineCommandURL = argv0URL.deletingLastPathComponent()
			.appendingPathComponent("Public").appendingPathComponent("docker-machine")

		guard fm.directoryExists(atPath: "/Library/ServiceData/Docker/machine/machines/default") else {
			try CreateMachineCommand.createRequiredDirectories()

			setuid(1) // drop privileges to daemon user

			// docker-machine create leaves the VM running after it is done
			try CreateMachineCommand.runDockerMachineCreate(logHandle: logHandle)
			waitForSigterm(logHandle: logHandle)
		}

		let argv = [ "start", "default" ]
		let stream = WriteStream.for(fileHandle: logHandle)
		let task = Task(executable: dockerMachineCommandURL.path, arguments: argv,
						stdout: stream, stderr: stream)

		let exitCode = task.runSync()
		guard exitCode == 0 else {
			log.log(type: .error, "docker-machine start failed")
			sleep(10) // stop launchd from restarting us in a loop
			exit(1)
		}

		waitForSigterm(logHandle: logHandle)
	}
}
