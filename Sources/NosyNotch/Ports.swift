import AppKit
import Darwin

/// A TCP port some process on this Mac is listening on, with who opened it.
struct ListeningPort: Identifiable, Equatable {
    var id: String { "\(pid):\(port)" }
    let port: Int
    let pid: pid_t
    /// The process name ("node", "python3.12", "Spotify").
    let process: String
    /// What it actually is: the script or command behind an interpreter ("vite", "next", "http.server").
    let label: String
    let path: String
    let command: String
    /// The process's working directory – usually the project.
    let cwd: String?
    let startedAt: Date?
    /// Listening on every interface (reachable from the network), not only on localhost.
    let exposed: Bool
    /// The agent somewhere above it in the process tree (it started the server).
    let agent: Agent?
    /// The first app above it (Ghostty, Cursor, the Claude app …), if any.
    let hostApp: String?
    let hostBundleID: String?
    /// All parents up to launchd – to match it with a session.
    let ancestors: [pid_t]
    /// A dev server or other command-line tool, as opposed to an app (Spotify, AirPlay, Raycast …).
    let isDev: Bool
    /// Quitting it would end an app or an agent – ask first.
    let needsConfirm: Bool

    /// "website" – the last part of the working directory, unless that's just the home folder.
    var folderName: String? {
        guard let cwd, cwd != "/", cwd != NSHomeDirectory() else { return nil }
        return (cwd as NSString).lastPathComponent
    }

    /// "Claude Code in Ghostty", "Cursor", "nothing (runs on its own)".
    var origin: String {
        switch (agent, hostApp) {
        case let (agent?, app?): return "\(agent.name) in \(app)"
        case let (agent?, nil): return agent.name
        case let (nil, app?): return app
        case (nil, nil): return "nothing (runs on its own)"
        }
    }

    /// Short origin for the chip: the agent if there is one, otherwise the app.
    var shortOrigin: String? { agent?.name ?? hostApp }
}

/// Finds listening TCP ports straight from the kernel (libproc) – no `lsof`, a few milliseconds per scan.
/// Only processes of the current user are visible; that's all that can be quit without a password anyway.
enum PortScan {
    private static let interpreters: Set<String> = [
        "node", "bun", "deno", "python", "python3", "ruby", "java", "php", "perl", "dotnet", "npm", "npx", "pnpm", "yarn",
    ]
    private static let agentNames: [String: Agent] = ["claude": .claude, "codex": .codex, "cursor-agent": .cursor]

    static func run() -> [ListeningPort] {
        let me = getuid()
        let own = getpid()
        var result: [ListeningPort] = []
        var seen = Set<String>()
        for pid in allPIDs() where pid > 0 && pid != own {
            let ports = listeningPorts(of: pid)
            guard !ports.isEmpty, let bsd = bsdInfo(pid), bsd.pbi_uid == me else { continue }
            let process = name(of: pid)
            let path = executablePath(of: pid) ?? process
            let args = arguments(of: pid)
            let label = label(process: process, args: args)
            let chain = ancestors(of: pid)
            var agent: Agent?
            var host: NSRunningApplication?
            for parent in chain {
                if agent == nil, let found = agentNames[commandName(of: parent)] { agent = found }
                // Regular apps and menu-bar apps (Raycast …); not background helpers.
                if let app = NSRunningApplication(processIdentifier: parent), app.activationPolicy != .prohibited {
                    host = app
                    break
                }
            }
            let ownApp = NSRunningApplication(processIdentifier: pid)
            // python.org's Python lives in a "Python.app" – an interpreter is never an app here.
            let isAppProcess = label == process
                && ((ownApp.map { $0.activationPolicy != .prohibited } ?? false) || path.contains(".app/"))
            let isSystem = ["/System/", "/usr/libexec/", "/usr/sbin/", "/Library/Apple/"].contains { path.hasPrefix($0) }
            // The agents' own sockets (IDE bridge, MCP) and Nosy Notch itself aren't servers you started.
            let isAgent = agentNames[normalized(process)] != nil
            let isSelf = process == "NosyNotch" || (ownApp?.bundleIdentifier).map { $0 == Bundle.main.bundleIdentifier } ?? false
            let fromDevTool = agent != nil || host.map(isDevTool) ?? false
            let isDev = !isAgent && !isSelf && !isSystem && (fromDevTool || (host == nil && !isAppProcess))
            let started = bsd.pbi_start_tvsec > 0 ? Date(timeIntervalSince1970: TimeInterval(bsd.pbi_start_tvsec)) : nil
            for (port, exposed) in ports.sorted(by: { $0.key < $1.key }) {
                let key = "\(pid):\(port)"
                guard seen.insert(key).inserted else { continue }
                result.append(ListeningPort(
                    port: port, pid: pid, process: process, label: label, path: path,
                    command: args.joined(separator: " "), cwd: workingDirectory(of: pid), startedAt: started,
                    exposed: exposed, agent: agent, hostApp: host?.localizedName, hostBundleID: host?.bundleIdentifier,
                    ancestors: chain, isDev: isDev, needsConfirm: !isDev))
            }
        }
        return result.sorted { $0.port < $1.port }
    }

    /// Ends the process holding the port: SIGTERM, and SIGKILL if it's still there after two seconds.
    static func quit(_ port: ListeningPort, completion: @escaping @MainActor () -> Void) {
        let pid = port.pid
        let started = bsdInfo(pid)?.pbi_start_tvsec
        Darwin.kill(pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            // Same PID and start time: still the same process, not a new one that got its number.
            if let info = bsdInfo(pid), info.pbi_start_tvsec == started { Darwin.kill(pid, SIGKILL) }
            DispatchQueue.main.async { MainActor.assumeIsolated { completion() } }
        }
    }

    // MARK: - libproc

    private static func allPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let filled = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        return Array(pids.prefix(Int(max(0, filled))))
    }

    /// Port → listening on every interface. A server on IPv4 and IPv6 counts once.
    private static func listeningPorts(of pid: pid_t) -> [Int: Bool] {
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return [:] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(size) / stride + 16)
        let filled = fds.withUnsafeMutableBytes { proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count)) }
        guard filled > 0 else { return [:] }

        var ports: [Int: Bool] = [:]
        for fd in fds.prefix(Int(filled) / stride) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var info = socket_fdinfo()
            let got = proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &info, Int32(MemoryLayout<socket_fdinfo>.size))
            guard got == Int32(MemoryLayout<socket_fdinfo>.size), info.psi.soi_kind == Int32(SOCKINFO_TCP) else { continue }
            let tcp = info.psi.soi_proto.pri_tcp
            guard tcp.tcpsi_state == Int32(TSI_S_LISTEN) else { continue }
            let ini = tcp.tcpsi_ini
            let port = Int(UInt16(bigEndian: UInt16(truncatingIfNeeded: ini.insi_lport)))
            guard port > 0 else { continue }
            let exposed: Bool
            if ini.insi_vflag & UInt8(INI_IPV6) != 0 {
                var addr = ini.insi_laddr.ina_6
                let bytes = withUnsafeBytes(of: &addr) { Array($0) }
                let loopback = bytes == [UInt8](repeating: 0, count: 15) + [1]
                exposed = !loopback
            } else {
                let addr = UInt32(bigEndian: ini.insi_laddr.ina_46.i46a_addr4.s_addr)
                exposed = addr >> 24 != 127
            }
            ports[port] = (ports[port] ?? false) || exposed
        }
        return ports
    }

    static func bsdInfo(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }

    private static func name(of pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "?" }
        return String(cString: buffer)
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { raw in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
        return path.isEmpty ? nil : path
    }

    /// Parents up to launchd. Via sysctl, which (unlike libproc) also works for root processes like `login`.
    private static func ancestors(of pid: pid_t) -> [pid_t] {
        var chain: [pid_t] = []
        var current = kinfo(pid)?.kp_eproc.e_ppid ?? 0
        while current > 1, chain.count < 32, !chain.contains(current) {
            chain.append(current)
            current = kinfo(current)?.kp_eproc.e_ppid ?? 0
        }
        return chain
    }

    private static func kinfo(_ pid: pid_t) -> kinfo_proc? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info
    }

    /// The short command name of any process (also root-owned ones).
    private static func commandName(of pid: pid_t) -> String {
        guard var info = kinfo(pid) else { return "" }
        let name = withUnsafeBytes(of: &info.kp_proc.p_comm) { raw in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
        return normalized(name)
    }

    /// "claude.exe" → "claude".
    private static func normalized(_ name: String) -> String {
        name.hasSuffix(".exe") ? String(name.dropLast(4)) : name
    }

    /// Terminals, editors and agent apps: whatever they start is yours to manage.
    private static let devToolBundles: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable",
        "com.github.wez.wezterm", "co.zeit.hyper", "net.kovidgoyal.kitty", "org.alacritty", "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92", "dev.zed.Zed", "com.exafunction.windsurf",
        "com.apple.dt.Xcode", "com.panic.Nova", "com.anthropic.claudefordesktop", "com.openai.codex",
        "com.vscodium", "com.sublimetext.4",
    ]

    private static func isDevTool(_ app: NSRunningApplication) -> Bool {
        guard let id = app.bundleIdentifier else { return false }
        return devToolBundles.contains(id) || id.hasPrefix("com.jetbrains.")
    }

    /// argv via KERN_PROCARGS2: argc, the executable path, padding, then the arguments.
    private static func arguments(of pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }   // executable path
        while index < size, buffer[index] == 0 { index += 1 }   // padding
        var args: [String] = []
        while index < size, args.count < argc {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            args.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return args
    }

    /// "node …/node_modules/.bin/vite" → "vite", "python3 -m http.server" → "http.server".
    static func label(process: String, args: [String]) -> String {
        let base = process.lowercased().split(separator: ".").first.map(String.init) ?? process
        let isInterpreter = interpreters.contains(base) || base.hasPrefix("python") || base.hasPrefix("ruby")
        guard isInterpreter, args.count > 1 else { return process }
        var rest = args.dropFirst()
        while let arg = rest.first {
            if arg == "-m", rest.count > 1 { return rest.dropFirst().first! }
            if arg.hasPrefix("-") { rest = rest.dropFirst(); continue }
            break
        }
        guard let script = rest.first else { return process }
        let url = URL(fileURLWithPath: script)
        var name = url.deletingPathExtension().lastPathComponent
        // ".../vite/bin/vite.js" is fine, ".../next/dist/bin/index.js" isn't – take the package instead.
        if ["index", "cli", "main", "server", "start", "app"].contains(name.lowercased()) {
            let parts = url.pathComponents
            if let modules = parts.lastIndex(of: "node_modules"), modules + 1 < parts.count {
                name = parts[modules + 1]
            } else if parts.count > 2 {
                name = parts[parts.count - 2]   // ".../agent_cockpit/server.js" → "agent_cockpit"
            }
        }
        if ["run", "exec", "dlx"].contains(name), rest.count > 1 { name += " " + rest.dropFirst().joined(separator: " ") }
        return name.isEmpty ? process : name
    }
}

/// Keeps the list of open ports fresh: often while you look at it, rarely otherwise.
@MainActor
final class PortMonitor: ObservableObject {
    @Published private(set) var ports: [ListeningPort] = []
    /// Ports being quit right now (shown fading out).
    @Published private(set) var closing: Set<String> = []

    var onChange: (() -> Void)?
    private var timer: Timer?
    private var scanning = false
    private var fast = false

    /// What the notch shows: dev servers, or everything with "include apps" on.
    var visible: [ListeningPort] {
        Preferences.portsShowAll ? ports : ports.filter(\.isDev)
    }

    /// Fast refresh while the hover view is open.
    func setWatching(_ watching: Bool) {
        guard Preferences.portsEnabled else { stop(); return }
        if watching { refresh() }
        guard timer == nil || fast != watching else { return }
        fast = watching
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: watching ? 3 : 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if !ports.isEmpty { ports = []; onChange?() }
    }

    func refresh() {
        guard !scanning, Preferences.portsEnabled else { return }
        scanning = true
        DispatchQueue.global(qos: .utility).async {
            let found = PortScan.run()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.scanning = false
                    guard found != self.ports else { return }
                    self.ports = found
                    self.closing = self.closing.filter { id in found.contains { $0.id == id } }
                    self.onChange?()
                }
            }
        }
    }

    func quit(_ port: ListeningPort) {
        closing.insert(port.id)
        PortScan.quit(port) { [weak self] in self?.refresh() }
    }

    /// For the recorder.
    func preview(_ ports: [ListeningPort]) {
        self.ports = ports
        onChange?()
    }

    /// Ports a session's agent started (it's in the process tree), or failing that, ones running in its folder.
    func ports(for session: Session) -> [ListeningPort] {
        visible.filter { port in
            if let pid = session.hostPID, port.ancestors.contains(pid) { return true }
            guard port.agent == session.agent, let cwd = session.cwd, let portCwd = port.cwd else { return false }
            return portCwd == cwd || portCwd.hasPrefix(cwd + "/")
        }
    }
}
