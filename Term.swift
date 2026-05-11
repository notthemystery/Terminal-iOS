import Foundation
import Darwin

// MARK: - ERRORS

enum ShellError: Error {
    case invalidCommand
    case binaryNotFound
    case spawnFailed
}

// MARK: - SHELL

struct Shell {

    static let toolDir = Bundle.main.bundlePath + "/tools/"

    // MARK: Pipeline

    static func runPipeline(_ input: String) throws -> String {

        let commands = input
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var data: Data? = nil

        for cmd in commands {
            data = try execute(cmd, input: data)
        }

        return String(data: data ?? Data(), encoding: .utf8) ?? ""
    }

    // MARK: Execute

    static func execute(_ command: String, input: Data?) throws -> Data {

        let parts = command
            .split(separator: " ")
            .map(String.init)

        guard let name = parts.first else {
            throw ShellError.invalidCommand
        }

        let args = Array(parts.dropFirst())
        let toolPath = toolDir + name

        if FileManager.default.fileExists(atPath: toolPath) {
            return try spawn(path: toolPath, args: args, input: input)
        }

        let bashPath = toolDir + "bash"

        if FileManager.default.fileExists(atPath: bashPath) {
            return try spawn(path: bashPath, args: ["-c", command], input: input)
        }

        throw ShellError.binaryNotFound
    }

    // MARK: Spawn (FIXED FOR XCODE 16+)

    static func spawn(path: String, args: [String], input: Data?) throws -> Data {

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        // Write stdin if provided
        if let input = input {
            stdinPipe.fileHandleForWriting.write(input)
        }
        stdinPipe.fileHandleForWriting.closeFile()

        // ✅ FIX: Proper allocation of posix_spawn_file_actions_t
        let fileActionsPtr =
            UnsafeMutablePointer<posix_spawn_file_actions_t>.allocate(capacity: 1)

        fileActionsPtr.initialize(to: posix_spawn_file_actions_t())

        defer {
            posix_spawn_file_actions_destroy(fileActionsPtr)
            fileActionsPtr.deinitialize(count: 1)
            fileActionsPtr.deallocate()
        }

        posix_spawn_file_actions_init(fileActionsPtr)

        // stdin
        let stdinFD: Int32

        if input == nil {
            stdinFD = open("/dev/null", O_RDONLY)
        } else {
            stdinFD = stdinPipe.fileHandleForReading.fileDescriptor
        }

        posix_spawn_file_actions_adddup2(
            fileActionsPtr,
            stdinFD,
            STDIN_FILENO
        )

        // stdout
        posix_spawn_file_actions_adddup2(
            fileActionsPtr,
            stdoutPipe.fileHandleForWriting.fileDescriptor,
            STDOUT_FILENO
        )

        // stderr
        posix_spawn_file_actions_adddup2(
            fileActionsPtr,
            stdoutPipe.fileHandleForWriting.fileDescriptor,
            STDERR_FILENO
        )

        // argv
        var argv: [UnsafeMutablePointer<CChar>?] =
            ([path] + args).map { strdup($0) }

        argv.append(nil)

        // env
        var env: [UnsafeMutablePointer<CChar>?] = [
            strdup("PATH=\(toolDir)"),
            nil
        ]

        var pid: pid_t = 0

        let status = posix_spawn(
            &pid,
            path,
            fileActionsPtr,
            nil,
            &argv,
            &env
        )

        // cleanup argv/env
        for ptr in argv where ptr != nil { free(ptr) }
        for ptr in env where ptr != nil { free(ptr) }

        guard status == 0 else {
            throw ShellError.spawnFailed
        }

        waitpid(pid, nil, 0)

        stdoutPipe.fileHandleForWriting.closeFile()

        return stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    }
}
