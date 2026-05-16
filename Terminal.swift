import SwiftUI
import Foundation

@main
struct TerminalApp: App {
    var body: some Scene {
        WindowGroup {
            TermView()
        }
    }
}

struct TermView: View {

    @State private var input = ""
    @State private var lines: [String] = [
        "iOS terminal ready",
        "tools runtime active",
        print(FileManager.default.isExecutableFile(atPath: toolPath))
        ""
    ]

    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines, id: \.self) { line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(Color.black)

            Divider().background(Color.green)

            HStack {
                Text("$")
                    .foregroundColor(.green)
                    .font(.system(.body, design: .monospaced))

                TextField("", text: $input)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(runCommand)
            }
            .padding()
            .background(Color.black)
        }
        .background(Color.black)
    }

    func runCommand() {
        let cmd = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }

        lines.append("$ \(cmd)")

        let result = Shell.run(cmd)
        lines.append(result.isEmpty ? "(no output)" : result)

        input = ""
    }
}

// MARK: - SHELL BRIDGE

struct Shell {

    static var toolDir: String {
        Bundle.main.bundleURL
            .appendingPathComponent("tools/")
            .path + "/"
    }

    static func run(_ command: String) -> String {

        let parts = command
            .split(separator: " ")
            .map(String.init)

        guard let tool = parts.first else {
            return "invalid command"
        }

        let toolPath = toolDir + tool

        var argv: [UnsafeMutablePointer<CChar>?] = parts.map { strdup($0) }
        argv.append(nil)

        defer {
            for arg in argv {
                if let arg = arg {
                    free(arg)
                }
            }
        }

        var outputPtr: UnsafeMutablePointer<CChar>? = nil

        let status = run_command(toolPath, &argv, &outputPtr)

        guard let outputPtr else {
            return "error: no output"
        }

        let output = String(cString: outputPtr)
        free(outputPtr)

        return status == 0 ? output : "ERROR \(status)\n\(output)"
    }
}
