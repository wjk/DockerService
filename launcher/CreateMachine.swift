import Foundation
import SwiftCLI
import CommandLineExtensions
import os.log

internal class CreateMachineCommand: Command {
	let name = "create-machine"
	let shortDescription = "Creates the Docker virtual machine if necessary."

	func execute() throws {
		guard getuid() == 0 else {
			print("error: This command must be run as root", to: &CommandLine.standardError)
			exit(-1)
		}

		let log = OSLog(subsystem: "me.sunsol.docker-machine-launcher", category: "CreateMachine")
		let fm = FileManager.default

		if !fm.directoryExists(atPath: "/Library/ServiceData/Docker/docker-machine") {
			log.log(type: .default, "/Library/ServiceData/Docker/docker-machine does not exist, creating it")
			try fm.createDirectory(atPath: "/Library/ServiceData/Docker/docker-machine", withIntermediateDirectories: true, attributes: nil)

			let attributes: [FileAttributeKey: Any] = [
				FileAttributeKey.ownerAccountName: "daemon",
				FileAttributeKey.posixPermissions: 0o755
			]
			try fm.setAttributes(attributes, ofItemAtPath: "/Library/ServiceData/Docker/docker-machine")
		}

		if !fm.directoryExists(atPath: "/Library/ServiceData/Docker/Shared") {
			log.log(type: .default, "/Library/ServiceData/Docker/Shared does not exist, creating it")
			try fm.createDirectory(atPath: "/Library/ServiceData/Docker/Shared", withIntermediateDirectories: true, attributes: nil)

			let attributes: [FileAttributeKey: Any] = [
				FileAttributeKey.ownerAccountName: "daemon",
				FileAttributeKey.groupOwnerAccountName: "staff",
				FileAttributeKey.posixPermissions: 0o775
			]
			try fm.setAttributes(attributes, ofItemAtPath: "/Library/ServiceData/Docker/docker-machine")
		}

		setuid(1) // drop privileges to 'daemon' user now that our required directories exist

		let argv0URL = URL(fileURLWithPath: CommandLine.arguments[0])
		let dockerMachineCommandURL = argv0URL.deletingLastPathComponent()
			.appendingPathComponent("Public").appendingPathComponent("docker-machine")

		if !fm.directoryExists(atPath: "/Library/ServiceData/Docker/docker-machine/machines/default") {
			log.log(type: .default, "Default Docker machine does not exist, creating it...")

			let argv = [
				"--storage-path", "/Library/ServiceData/Docker/docker-machine",
				"create", "-d", "xhyve", "--xhyve-uuid", "44A05926-6238-43F6-99F2-522951DADF92",
				"--xhyve-experimental-nfs-share", "/Library/ServiceData/Docker/Shared",
				"default"
			]

			let task = Task(executable: dockerMachineCommandURL.path, arguments: argv,
							stdout: WriteStream.stdout, stderr: WriteStream.stderr)
			let exitCode = task.runSync()

			if exitCode == 0 {
				log.log(type: .default, "docker-machine creation succeeded")
				exit(0)
			} else {
				log.log(type: .error, "docker-machine create failed, details written to standard output")
				exit(1)
			}
		}
	}
}
