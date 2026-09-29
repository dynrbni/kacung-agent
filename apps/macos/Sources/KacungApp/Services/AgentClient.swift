import Foundation

public final class AgentClient: ObservableObject {
    public static let shared = AgentClient()

    private let baseURL: URL
    private let wsURL: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession

    @Published public var isConnected = false

    public var onStateChanged: ((AssistantState) -> Void)?
    public var onConfirmationRequired: ((ConfirmationRequest) -> Void)?
    public var onSpeechStart: ((String) -> Void)?
    public var onSpeechEnd: ((String) -> Void)?
    public var onError: ((String) -> Void)?

    private init(host: String = "127.0.0.1", port: Int = 3847) {
        self.baseURL = URL(string: "http://\(host):\(port)")!
        self.wsURL = URL(string: "ws://\(host):\(port)/ws")!
        self.urlSession = URLSession(configuration: .default)
    }

    public func connect() {
        disconnect()
        webSocketTask = urlSession.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        listenForMessages()
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }

    public func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
                // Keep listening
                self.listenForMessages()

            case .failure(let error):
                print("WebSocket error: \(error)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                // Reconnect after delay
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.connect()
                }
            }
        }
    }

    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        DispatchQueue.main.async {
            switch type {
            case "state_change":
                if let payload = json["payload"] as? [String: Any],
                   let newStateStr = payload["newState"] as? String,
                   let state = AssistantState(rawValue: newStateStr) {
                    self.onStateChanged?(state)
                }

            case "confirmation_required":
                if let payload = json["payload"] as? [String: Any],
                   let payloadData = try? JSONSerialization.data(withJSONObject: payload),
                   let req = try? JSONDecoder().decode(ConfirmationRequest.self, from: payloadData) {
                    self.onConfirmationRequired?(req)
                }

            case "speech_start":
                if let payload = json["payload"] as? [String: Any],
                   let text = payload["text"] as? String {
                    self.onSpeechStart?(text)
                }

            case "speech_end":
                if let payload = json["payload"] as? [String: Any],
                   let text = payload["text"] as? String {
                    self.onSpeechEnd?(text)
                }

            case "error":
                if let payload = json["payload"] as? [String: Any],
                   let errorMsg = payload["error"] as? String {
                    self.onError?(errorMsg)
                }

            default:
                break
            }
        }
    }

    public func sendQuery(text: String, completion: @escaping (Result<AgentQueryResponse, Error>) -> Void) {
        let endpoint = baseURL.appendingPathComponent("query")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "AgentClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            do {
                let res = try JSONDecoder().decode(AgentQueryResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(res)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    public func sendConfirmation(id: String, approved: Bool, reason: String? = nil) {
        let endpoint = baseURL.appendingPathComponent("confirm")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "id": id,
            "approved": approved
        ]
        if let reason = reason {
            payload["reason"] = reason
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        urlSession.dataTask(with: request).resume()
    }

    public func sendWake() {
        let endpoint = baseURL.appendingPathComponent("wake")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        urlSession.dataTask(with: request).resume()
    }

    public func sendReset() {
        let endpoint = baseURL.appendingPathComponent("reset")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        urlSession.dataTask(with: request).resume()
    }
}
