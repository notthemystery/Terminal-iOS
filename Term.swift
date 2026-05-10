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
    @State private var lines: [String] = ["mini shell ready\n"]

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
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                .background(Color.black)
                .onChange(of: lines.count) {
                    proxy.scrollTo(lines.count - 1, anchor: .bottom)
                }
            }

            // INPUT
            HStack {
                Text("$")
                    .foregroundColor(.green)
                    .font(.system(.body, design: .monospaced))

                TextField("", text: $input)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { run() }
            }
            .padding()
            .background(Color.black)
        }
    }

    // MARK: - EXECUTION ENTRY

    func run() {
        let cmd = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }

        lines.append("$ \(cmd)")

        do {
            let out = try Shell.runPipeline(cmd)
            lines.append(out.isEmpty ? "(no output)" : out)
        } catch {
            lines.append("error: \(error)")
        }

        input = ""
    }
}

// MARK: - SHELL ERRORS

enum ShellError: Error {
    case invalidCommand
    case binaryNotFound
    case spawnFailed
}

// MARK: - SHELL ENGINE

struct Shell {

    static let toolDir = Bundle.main.bundlePath + "/tools/"

    // MARK: Pipeline
    static func runPipeline(_ input: String) throws -> String {

        let commands = input.split(separator: "|").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var data: Data? = nil

        for cmd in commands {
            data = try execute(cmd, input: data)
        }

        return String(data: data ?? Data(), encoding: .utf8) ?? ""
    }

    // MARK: Command resolver (tools → bash fallback)
    static func execute(_ command: String, input: Data?) throws -> Data {

        let parts = command.split(separator: " ").map(String.init)
        guard let name = parts.first else {
            throw ShellError.invalidCommand
        }

        let args = Array(parts.dropFirst())
        let toolPath = toolDir + name

        // 1. Run bundled tool
        if FileManager.default.fileExists(atPath: toolPath) {
            return try spawn(path: toolPath, args: args, input: input)
        }

        // 2. Fallback to bash (if available)
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

    // MARK: Process runner (safe posix_spawn)
    static func spawn(path: String, args: [String], input: Data?) throws -> Data {

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        // write input if exists
        if let input = input {
            stdinPipe.fileHandleForWriting.write(input)
        }
        stdinPipe.fileHandleForWriting.closeFile()

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)

        // STDIN
        let stdinFD: Int32 = input == nil
            ? open("/dev/null", O_RDONLY)
            : stdinPipe.fileHandleForReading.fileDescriptor

        posix_spawn_file_actions_adddup2(
            &fileActions,
            stdinFD,
            STDIN_FILENO
        )

        // STDOUT
        posix_spawn_file_actions_adddup2(
            &fileActions,
            stdoutPipe.fileHandleForWriting.fileDescriptor,
            STDOUT_FILENO
        )

        posix_spawn_file_actions_adddup2(
            &fileActions,
            stdoutPipe.fileHandleForWriting.fileDescriptor,
            STDERR_FILENO
        )

        var pid: pid_t = 0

        var argv = [path] + args
        let cargv = argv.map { strdup($0) } + [nil]

        let env: [UnsafeMutablePointer<CChar>?] = [
            strdup("PATH=\(toolDir)"),
            nil
        ]

        let status = posix_spawn(
            &pid,
            path,
            &fileActions,
            nil,
            cargv,
            env
        )

        guard status == 0 else {
            throw ShellError.spawnFailed
        }

        waitpid(pid, nil, 0)

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return data
    }
}
