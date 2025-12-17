import SwiftUI
import AppKit
import ServiceManagement

let appVersion = "1.0.0"
let appBuild = "1"

@main
struct AmirrorApp: App {
    @StateObject var deviceManager = DeviceManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Amirror", systemImage: "flipphone") {
            MenuBarView()
                .environmentObject(deviceManager)
                .frame(width: 300)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Make this an agent app (no dock icon, menu bar only)
        NSApp.setActivationPolicy(.accessory)
    }
}

class DeviceManager: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var mirroringDevices: Set<String> = []  // Track devices being mirrored
    
    private var timer: Timer?
    private var scrcpyProcesses: [String: Process] = [:]  // Track scrcpy processes by device serial
    
    init() {
        refreshDevices()
        // Check for device changes every 10 seconds (reduced polling for smoother UI)
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.refreshDevices()
        }
    }
    
    func refreshDevices() {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                self.isLoading = true
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/adb")
            process.arguments = ["devices"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    self.parseDevices(from: output)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to get devices: \(error.localizedDescription)"
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func parseDevices(from output: String) {
        var parsedDevices: [Device] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("device") && !trimmed.contains("List") && !trimmed.isEmpty {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 1 {
                    let serial = parts[0]
                    parsedDevices.append(Device(serial: serial, name: getDeviceName(serial: serial)))
                }
            }
        }
        
        DispatchQueue.main.async {
            self.devices = parsedDevices
            self.errorMessage = nil
        }
    }
    
    private func getDeviceName(serial: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/adb")
        process.arguments = ["-s", serial, "shell", "getprop", "ro.product.model"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let name = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? serial : name
            }
        } catch {
            return serial
        }
        
        return serial
    }
    
    func toggleMirror(for device: Device) {
        if mirroringDevices.contains(device.serial) {
            stopMirror(for: device)
        } else {
            startMirror(for: device)
        }
    }
    
    func startMirror(for device: Device) {
        print("Starting mirror for device: \(device.serial)")
        
        // Use the same scrcpy options as amirror.sh
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/scrcpy")
        task.arguments = [
            "--serial=\(device.serial)",
            "--prefer-text",
            "--turn-screen-off",
            "--stay-awake",
            "--window-title=Amirror - \(device.name)"
        ]
        
        // Set up environment to ensure all tools can be found
        // Include GNU coreutils path like amirror.sh does
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        task.environment = environment
        
        // Pipe stderr to capture any errors
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        do {
            try task.run()
            print("scrcpy launched successfully for \(device.serial)")
            
            // Track the process and update state
            scrcpyProcesses[device.serial] = task
            DispatchQueue.main.async {
                self.mirroringDevices.insert(device.serial)
            }
            
            // Monitor for process termination
            DispatchQueue.global(qos: .background).async {
                task.waitUntilExit()
                DispatchQueue.main.async {
                    self.mirroringDevices.remove(device.serial)
                    self.scrcpyProcesses.removeValue(forKey: device.serial)
                    print("Mirror stopped for \(device.serial)")
                }
            }
            
            // Bring scrcpy window to front after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.bringScrcpyToFront()
            }
        } catch {
            print("Failed to launch scrcpy: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start mirror: \(error.localizedDescription)"
            }
        }
    }
    
    func stopMirror(for device: Device) {
        print("Stopping mirror for device: \(device.serial)")
        
        if let process = scrcpyProcesses[device.serial] {
            process.terminate()
            scrcpyProcesses.removeValue(forKey: device.serial)
            DispatchQueue.main.async {
                self.mirroringDevices.remove(device.serial)
            }
        }
    }
    
    private func bringScrcpyToFront() {
        // Find and activate scrcpy app
        let runningApps = NSWorkspace.shared.runningApplications
        if let scrcpyApp = runningApps.first(where: { $0.localizedName == "scrcpy" || $0.bundleIdentifier?.contains("scrcpy") == true }) {
            scrcpyApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            print("Brought scrcpy to front")
        } else {
            // Fallback: use AppleScript to bring scrcpy window to front
            let script = """
            tell application "System Events"
                set frontmost of (first process whose name contains "scrcpy") to true
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("AppleScript error: \(error)")
                } else {
                    print("Brought scrcpy to front via AppleScript")
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct Device: Identifiable {
    let id = UUID()
    let serial: String
    let name: String
}

struct DeviceRow: View {
    let device: Device
    let isMirroring: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            print("Button tapped for device: \(device.serial), currently mirroring: \(isMirroring)")
            onTap()
        }) {
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(isMirroring ? .green : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(isMirroring ? "Mirroring..." : device.serial)
                        .font(.system(size: 10))
                        .foregroundColor(isMirroring ? .green : .secondary)
                }
                Spacer()
                Image(systemName: isMirroring ? "stop.circle.fill" : "play.circle.fill")
                    .foregroundColor(isMirroring ? .red : .green)
                    .font(.system(size: 16))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderless)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isMirroring ? Color.green.opacity(0.1) : Color(.controlBackgroundColor).opacity(0.5))
        )
    }
}

struct MenuBarView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Android Devices")
                    .font(.headline)
                Spacer()
                Button(action: {
                    deviceManager.refreshDevices()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            Divider()
            
            if deviceManager.devices.isEmpty {
                Text("No devices detected")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(deviceManager.devices) { device in
                        DeviceRow(
                            device: device,
                            isMirroring: deviceManager.mirroringDevices.contains(device.serial)
                        ) {
                            deviceManager.toggleMirror(for: device)
                        }
                    }
                }
                .padding()
            }
            
            if let error = deviceManager.errorMessage {
                Divider()
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .padding()
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    SettingsView()
                }
                
                Spacer()
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark")
                    Text("Quit")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12))
            .padding()
        }
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
            
            Divider()
            
            // Auto-launch toggle
            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Login")
                        .font(.system(size: 13))
                    Text("Automatically start when you log in")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: launchAtLogin) { newValue in
                setLaunchAtLogin(enabled: newValue)
            }
            
            Divider()
            
            // Version info
            VStack(alignment: .leading, spacing: 4) {
                Text("About")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(appVersion) (\(appBuild))")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 12))
                
                HStack {
                    Text("App Name")
                    Spacer()
                    Text("Amirror")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 12))
            }
            
            Divider()
            
            // Links
            HStack {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }
        }
        .padding()
        .frame(width: 280)
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
}
