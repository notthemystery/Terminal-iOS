import SwiftUI
import Foundation

// MARK: - APP

@main
struct TerminalApp: App {
    var body: some Scene {
        WindowGroup {
            TermView()
        }
    }
}

// MARK: - UI

struct TermView: View {

    @State private var input = ""
    @State private var lines: [String] = [
        "iOS terminal ready",
        "tools-based shell loaded",
        ""
    ]

    var body: some View {
        VStack(spacing: 0) {

            // OUTPUT
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
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

            Divider().background(Color.green)

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
                    .onSubmit(run)
            }
            .padding()
            .background(Color.black)
        }
        .background(Color.black)
    }

    // MARK: RUN

    func run() {

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
        Bundle.main.bundlePath + "/tools/"
    }

    static func run(_ command: String) -> String {

        let parts = command.split(separator: " ").map(String.init)
        guard let tool = parts.first else { return "" }

        let toolPath = toolDir + tool

        var outputPtr: UnsafeMutablePointer<CChar>? = nil

        let status = run_command(toolPath, command, &outputPtr)

        guard status == 0, let outputPtr else {
            return "error: \(status)"
        }

        let output = String(cString: outputPtr)
        free(outputPtr)

        return output
    }
}
