import Foundation
import Network

/// Tiny HTTP server bound to the loopback interface. Claude Code hooks `curl` their JSON payload here.
///
///   POST /event   – body: hook stdin JSON
///   GET  /health  – returns "ok"
///   POST /quit    – terminates the app (used by `npx nosynotch stop`)
final class EventServer {
    static let defaultPort: UInt16 = 7823

    let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "dev.davidkubus.nosynotch.server")
    private let onEvent: @Sendable (HookEvent) -> Void
    var onQuit: (@Sendable () -> Void)?

    private(set) var lastError: String?

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
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.lastError = error.localizedDescription
                NSLog("NosyNotch: server failed: \(error)")
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
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
        let status: String
        switch (request.method, request.path) {
        case ("POST", "/event"):
            if let event = HookEvent(data: request.body, headers: request.headers) {
                onEvent(event)
                status = "200 OK"
            } else {
                status = "400 Bad Request"
            }
        case ("GET", "/health"):
            status = "200 OK"
        case ("POST", "/quit"):
            status = "200 OK"
            if let onQuit { queue.asyncAfter(deadline: .now() + 0.1) { onQuit() } }
        default:
            status = "404 Not Found"
        }
        let body = status.hasPrefix("200") ? "ok" : status
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
    let headers: [String: String]
    let body: Data

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

        let length = headers["content-length"].flatMap(Int.init) ?? 0
        let bodyStart = headerEnd.upperBound
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else { return nil }
        let bodyEnd = buffer.index(bodyStart, offsetBy: length)

        self.method = String(requestLine[0]).uppercased()
        let target = String(requestLine[1])
        self.path = target.split(separator: "?", maxSplits: 1).first.map(String.init) ?? target
        self.headers = headers
        self.body = Data(buffer[bodyStart..<bodyEnd])
    }
}
