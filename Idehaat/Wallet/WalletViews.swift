import SwiftUI
import PassKit

/// Apple's official "Add to Apple Wallet" button (required by Apple's design guidelines).
struct AddToWalletButton: UIViewRepresentable {
    var action: () -> Void

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

struct PassItem: Identifiable {
    let id = UUID()
    let pass: PKPass
}

/// Presents Apple's add-pass sheet.
struct AddPassSheet: UIViewControllerRepresentable {
    let pass: PKPass
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        guard let controller = PKAddPassesViewController(pass: pass) else {
            return UIViewController()
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) { dismiss() }
    }
}
