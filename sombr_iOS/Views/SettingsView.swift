import SwiftUI

struct SettingsView: View {

    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                authSection
                testSection
            }
            .navigationTitle("Settings")
            .onDisappear { vm.save() }
        }
    }

    // MARK: - Sections

    private var connectionSection: some View {
        Section("SSH Connection") {
            LabeledContent("Host") {
                TextField("192.168.1.100", text: $vm.host)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Port") {
                TextField("22", text: $vm.port)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Username") {
                TextField("chromebook_user", text: $vm.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var authSection: some View {
        Section("Authentication") {
            Picker("Method", selection: $vm.authChoice) {
                ForEach(AuthMethodChoice.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            if vm.authChoice == .privateKey {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private Key (OpenSSH format)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $vm.privateKey)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            } else {
                SecureField("Password", text: $vm.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var testSection: some View {
        Section {
            Button {
                vm.save()
                vm.testConnection()
            } label: {
                HStack {
                    Spacer()
                    if vm.testState == .testing {
                        ProgressView()
                            .padding(.trailing, 6)
                        Text("Testing…")
                    } else {
                        Text("Test Connection")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(vm.testState == .testing)

            testResultBanner
        }
    }

    @ViewBuilder
    private var testResultBanner: some View {
        switch vm.testState {
        case .idle:
            EmptyView()
        case .testing:
            EmptyView()
        case .success(let msg):
            Label(msg, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.footnote)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.footnote)
        }
    }
}

#Preview {
    SettingsView()
}
