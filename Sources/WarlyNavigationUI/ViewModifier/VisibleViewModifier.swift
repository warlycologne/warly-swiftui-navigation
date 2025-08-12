import SwiftUI

extension View {
    func onVisibilityChange(update: Binding<Bool>) -> some View {
        background(VisibleViewModifier(update: update))
    }
}

private struct VisibleViewModifier: UIViewControllerRepresentable {
    let update: Binding<Bool>

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = ViewWillDisappearViewController()
        viewController.update = update
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Does nothing
    }

    private class ViewWillDisappearViewController: UIViewController {
        var update: Binding<Bool>?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            update?.wrappedValue = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            update?.wrappedValue = false
        }
    }
}
