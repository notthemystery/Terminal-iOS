import SwiftUI
import Foundation

// MARK: - APP

@main
struct TerminalApp: App {

    var body: some Scene {
        WindowGroup {
            TermView()
                .background(Color.black)
        }
    }
}

// MARK: - UI

struct TermView: View {

    @State private var input = ""
    @State private var lines: [String] = [
        "mini shell ready",
        "type commands below",
        ""
    ]

    var body: some View {

        VStack(spacing: 0) {

            // OUTPUT

            ScrollViewReader { proxy in

                ScrollView {

                    VStack(alignment: .leading, spacing: 4) {

                        ForEach(lines.indices, id: \.self) { i in

                            Text(lines[i])
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .id(i)
                        }
                    }
                    .padding()
                }
                .background(Color.black)
                .onChange(of: lines.count) { _ in

                    if lines.count > 0 {
                        proxy.scrollTo(lines.count - 1, anchor: .bottom)
                    }
                }
            }

            Divider()
                .overlay(Color.green)

            // INPUT

            HStack(alignment: .center, spacing: 8) {

                Text("$")
                    .foregroundColor(.green)
                    .font(.system(.body, design: .monospaced))

                TextField("", text: $input)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit {
                        run()
                    }
            }
            .padding()
            .background(Color.black)
        }
        .background(Color.black)
    }

    // MARK: - RUN COMMAND

    func run() {

        let cmd = input.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cmd.isEmpty else {
            return
        }

        lines.append("$ \(cmd)")

        do {

            let out = try Shell.runPipeline(cmd)

            if out.isEmpty {
                lines.append("(no output)")
            } else {
                lines.append(out)
            }

        } catch {

            lines.append("error: \(error)")
        }

        input = ""
    }
}

// MARK: - ERRORS

enum ShellError: Error {
    case invalidCommand
    case binaryNotFound
    case spawnFailed
}

// MARK: - SHELL

struct Shell {

    static let toolDir =
        Bundle.main.bundlePath + "/tools/"

    // MARK: Pipeline

    static func runPipeline(_ input: String) throws -> String {

        let commands = input
            .split(separator: "|")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }

        var data: Data? = nil

        for cmd in commands {
            data = try execute(cmd, input: data)
        }

        return String(
            data: data ?? Data(),
            encoding: .utf8
        ) ?? ""
    }

    // MARK: Execute

    static func execute(
        _ command: String,
        input: Data?
    ) throws -> Data {

        let parts = command
            .split(separator: " ")
            .map(String.init)

        guard let name = parts.first else {
            throw ShellError.invalidCommand
        }

        let args = Array(parts.dropFirst())

        let toolPath = toolDir + name

        // bundled tool

        if FileManager.default.fileExists(atPath: toolPath) {

            return try spawn(
                path: toolPath,
                args: args,
                input: input
            )
        }

        // fallback to bash

        let bashPath = toolDir + "bash"

        if FileManager.default.fileExists(atPath: bashPath) {

            return try spawn(
                path: bashPath,
                args: ["-c", command],
                input: input
            )
        }

        throw ShellError.binaryNotFound
    }

    // MARK: Spawn

    static func spawn(
        path: String,
        args: [String],
        input: Data?
    ) throws -> Data {

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        // write stdin

        if let input = input {
            stdinPipe.fileHandleForWriting.write(input)
        }

        stdinPipe.fileHandleForWriting.closeFile()

        // file actions

        var fileActions = posix_spawn_file_actions_t()

        var fileActions = posix_spawn_file_actions_t(bitPattern: 0)

        // stdin

        let stdinFD: Int32

        if input == nil {

            stdinFD = open("/dev/null", O_RDONLY)

        } else {

            stdinFD =
                stdinPipe
                    .fileHandleForReading
                    .fileDescriptor
        }

        posix_spawn_file_actions_adddup2(
            &fileActions,
            stdinFD,
            STDIN_FILENO
        )

        // stdout

        posix_spawn_file_actions_adddup2(
            &fileActions,
            stdoutPipe
                .fileHandleForWriting
                .fileDescriptor,
            STDOUT_FILENO
        )

        // stderr

        posix_spawn_file_actions_adddup2(
            &fileActions,
            stdoutPipe
                .fileHandleForWriting
                .fileDescriptor,
            STDERR_FILENO
        )

        var pid: pid_t = 0

        // argv

        var argv:
            [UnsafeMutablePointer<CChar>?] =
                ([path] + args)
                    .map { strdup($0) }

        argv.append(nil)

        // env

        var env:
            [UnsafeMutablePointer<CChar>?] = [
                strdup("PATH=\(toolDir)"),
                nil
            ]

        let status = posix_spawn(
            &pid,
            path,
            &fileActions,
            nil,
            &argv,
            &env
        )

        // cleanup

        for ptr in argv where ptr != nil {
            free(ptr)
        }

        for ptr in env where ptr != nil {
            free(ptr)
        }

        posix_spawn_file_actions_destroy(
            &fileActions
        )

        guard status == 0 else {
            throw ShellError.spawnFailed
        }

        waitpid(pid, nil, 0)

        stdoutPipe
            .fileHandleForWriting
            .closeFile()

        let data =
            stdoutPipe
                .fileHandleForReading
                .readDataToEndOfFile()

        return data
    }
}
