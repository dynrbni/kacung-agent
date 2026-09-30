import SwiftUI

public struct ConfirmationModalView: View {
    public let request: ConfirmationRequest
    public let onApprove: () -> Void
    public let onDeny: () -> Void

    public init(request: ConfirmationRequest, onApprove: @escaping () -> Void, onDeny: @escaping () -> Void) {
        self.request = request
        self.onApprove = onApprove
        self.onDeny = onDeny
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(request.permissionLevel == "DANGEROUS" ? .red : .orange)
                    .font(.system(size: 20))

                Text("Action Confirmation Required")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text(request.permissionLevel)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(request.permissionLevel == "DANGEROUS" ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundColor(request.permissionLevel == "DANGEROUS" ? .red : .orange)
                    .cornerRadius(6)
            }

            Text("Lafly needs your permission to execute:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Tool:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(request.toolName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .fontDesign(.monospaced)
                }

                Text(request.description)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
            }

            HStack(spacing: 12) {
                Button(action: onDeny) {
                    Text("Deny")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button(action: onApprove) {
                    Text("Approve")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 12)
    }
}
