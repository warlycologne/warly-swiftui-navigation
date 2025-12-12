import SwiftUI

extension View {
    func onLifecycleEvent(onEvent: @escaping (ViewLifecycleEvent) -> Void) -> some View {
        background(ViewLifecycleEventViewModifier(onEvent: onEvent))
    }
}

enum ViewLifecycleEvent {
    case willAppear, didAppear
    case willDisappear, didDisappear
}

private struct ViewLifecycleEventViewModifier: UIViewControllerRepresentable {
    let onEvent: (ViewLifecycleEvent) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = ViewApearingViewController()
        viewController.onEvent = onEvent
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Does nothing
    }

    private class ViewApearingViewController: UIViewController {
        var onEvent: ((ViewLifecycleEvent) -> Void)?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            onEvent?(.willAppear)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onEvent?(.didAppear)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            onEvent?(.willDisappear)
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            onEvent?(.didDisappear)
        }
    }
}
