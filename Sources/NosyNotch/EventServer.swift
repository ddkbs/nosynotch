import Foundation
import Network

/// Tiny HTTP server bound to the loopback interface. Claude Code hooks `curl` their JSON payload here.
///
///   POST /event   – body: hook stdin JSON
///   POST /permission – body: PermissionRequest hook JSON; the response (the hook's stdout) is held back
///                    until the user decides in the notch
///   POST /usage   – body: Claude Code status line JSON (rate limits)
///   GET  /health  – returns "ok"
///   POST /quit    – terminates the app (used by `npx nosynotch stop`)
///   POST /settings – opens the settings window (used by `npx nosynotch settings`)
/// State is only touched on `queue` (and set up before `start()`), hence `@unchecked Sendable`.
final class EventServer: @unchecked Sendable {
    static let defaultPort: UInt16 = 7823

    let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "dev.davidkubus.nosynotch.server")
    private let onEvent: @Sendable (HookEvent) -> Void
    var onQuit: (@Sendable () -> Void)?
    var onSettings: (@Sendable () -> Void)?
    var onUsage: (@Sendable (Data) -> Void)?
    /// A permission hook waits for an answer. Call `reply` exactly once with the hook's stdout (nil = no decision).
    var onPermission: (@Sendable (HookEvent, @escaping @Sendable (String?) -> Void) -> Void)?

    private(set) var lastError: String?
    private var stopped = false

    init(port: UInt16 = EventServer.defaultPort, onEvent: @escaping @Sendable (HookEvent) -> Void) {
        self.port = port
        self.onEvent = onEvent
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .loopback

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "NosyNotch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }
        let listener = try NWListener(using: params, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.lastError = nil
            case .waiting(let error):
                self.lastError = error.localizedDescription
                NSLog("NosyNotch: server waiting (\(error))")
            case .failed(let error):
                // E.g. the port was still taken by a previous instance – try again instead of staying deaf.
                self.lastError = error.localizedDescription
                NSLog("NosyNotch: server not listening (\(error)), retrying")
                listener?.cancel()
                self.queue.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, self.listener === listener, !self.stopped else { return }
                    try? self.start()
                }
            default:
                break
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        stopped = true
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if let request = HTTPRequest(parsing: buffer) {
                self.respond(to: request, on: connection)
                return
            }
            if isComplete || error != nil || buffer.count > 8 * 1024 * 1024 {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buffer)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        // Hooks and the CLI use curl / Node, which never send these headers. Browsers do, so a web page
        // can't quit the app or show fake events with a `no-cors` request to localhost.
        if request.isFromBrowser {
            return send("403 Forbidden", body: "403 Forbidden", on: connection)
        }
        if request.method == "POST", request.path == "/permission" {
            guard let event = HookEvent(data: request.body, headers: request.headers, query: request.query) else {
                return send("400 Bad Request", body: "400 Bad Request", on: connection)
            }
            onEvent(event)
            guard let onPermission else { return send("200 OK", body: "", on: connection) }
            onPermission(event) { [weak self] output in
                self?.queue.async { self?.send("200 OK", body: output ?? "", on: connection) }
            }
            return
        }

        let status: String
        switch (request.method, request.path) {
        case ("POST", "/event"):
            if let event = HookEvent(data: request.body, headers: request.headers, query: request.query) {
                onEvent(event)
                status = "200 OK"
            } else {
                status = "400 Bad Request"
            }
        case ("POST", "/usage"):
            status = "200 OK"
            onUsage?(request.body)
        case ("GET", "/health"):
            status = "200 OK"
        case ("POST", "/quit"):
            status = "200 OK"
            if let onQuit { queue.asyncAfter(deadline: .now() + 0.1) { onQuit() } }
        case ("POST", "/settings"):
            status = "200 OK"
            onSettings?()
        default:
            status = "404 Not Found"
        }
        send(status, body: status.hasPrefix("200") ? "ok" : status, on: connection)
    }

    private func send(_ status: String, body: String, on connection: NWConnection) {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

/// Minimal HTTP/1.1 request parser – returns nil until the full request (headers + body) has arrived.
struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data

    /// Browsers send `Origin` and/or `Sec-Fetch-Site` with every cross-site request; curl and Node's fetch
    /// (the hooks and the CLI) send neither. (Node does send `Sec-Fetch-Mode`, so that one isn't checked.)
    var isFromBrowser: Bool {
        headers["origin"] != nil || headers["sec-fetch-site"] != nil
    }

    init?(parsing buffer: Data) {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let head = String(data: buffer[buffer.startIndex..<headerEnd.lowerBound], encoding: .utf8) else { return nil }

        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let length = max(0, headers["content-length"].flatMap(Int.init) ?? 0)
        let bodyStart = headerEnd.upperBound
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else { return nil }
        let bodyEnd = buffer.index(bodyStart, offsetBy: length)

        self.method = String(requestLine[0]).uppercased()
        let target = String(requestLine[1])
        let parts = target.split(separator: "?", maxSplits: 1)
        self.path = parts.first.map(String.init) ?? target
        var query: [String: String] = [:]
        if parts.count == 2 {
            for item in URLComponents(string: "?" + parts[1])?.queryItems ?? [] { query[item.name] = item.value ?? "" }
        }
        self.query = query
        self.headers = headers
        self.body = Data(buffer[bodyStart..<bodyEnd])
    }
}
