/// The delay choices for the Self-Timer (requirements §3.1 item 7: "e.g., 3/5/10s").
public enum SelfTimerDelay: Int, Codable, CaseIterable, Sendable {
    case three = 3
    case five = 5
    case ten = 10

    public var seconds: Int { rawValue }
}
