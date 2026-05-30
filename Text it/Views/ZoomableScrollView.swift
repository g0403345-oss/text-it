//
//  ZoomableScrollView.swift
//  Text it
//
//  UIScrollView-basierter Container mit nativem Pinch-to-Zoom (iOS).
//  Enthält UIPencilInteraction für Doppeltippen-Geste und automatische
//  Stift/Finger-Erkennung via UIGestureRecognizer.
//

#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - Public API

struct ZoomableScrollView<Content: View>: UIViewControllerRepresentable {
    @Binding var zoomScale: CGFloat
    var pageID: UUID?
    var onPencilDoubleTap: (() -> Void)?
    var onPencilDetected: (() -> Void)?
    var onFingerDetected: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    func makeUIViewController(context: Context) -> ZoomViewController {
        let vc = ZoomViewController()
        vc.zoomScaleDidChange = { scale in
            Task { @MainActor in zoomScale = scale }
        }
        return vc
    }

    func updateUIViewController(_ vc: ZoomViewController, context: Context) {
        if pageID != context.coordinator.lastPageID {
            context.coordinator.lastPageID = pageID
            vc.scrollView.setZoomScale(1.0, animated: false)
            vc.scrollView.setContentOffset(.zero, animated: false)
            Task { @MainActor in zoomScale = 1.0 }
        }

        let wrapped = AnyView(
            content()
                .environment(appState)
                .modelContext(modelContext)
        )
        vc.update(rootView: wrapped)

        // Callbacks für Pencil-Interaktion
        vc.onPencilDoubleTap = onPencilDoubleTap
        vc.onPencilDetected  = onPencilDetected
        vc.onFingerDetected  = onFingerDetected

        if abs(vc.scrollView.zoomScale - zoomScale) > 0.01 {
            vc.scrollView.setZoomScale(zoomScale, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastPageID: UUID? = nil
    }
}

// MARK: - UIViewController

final class ZoomViewController: UIViewController, UIScrollViewDelegate, UIPencilInteractionDelegate {
    let scrollView = UIScrollView()
    private let hostingController = UIHostingController(rootView: AnyView(EmptyView()))
    private var touchDetector: TouchTypeGesture?

    var zoomScaleDidChange: ((CGFloat) -> Void)?
    var onPencilDoubleTap: (() -> Void)?
    var onPencilDetected: (() -> Void)?
    var onFingerDetected: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        // Scroll View
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.4
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.bouncesZoom = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.backgroundColor = .clear

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostingController.view)
        let widthEqualFrame = hostingController.view.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor)
        widthEqualFrame.priority = .defaultHigh
        let widthMinContent = hostingController.view.widthAnchor.constraint(
            greaterThanOrEqualToConstant: 900)
        widthMinContent.priority = .required
        NSLayoutConstraint.activate([
            widthEqualFrame,
            widthMinContent,
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)

        // Apple Pencil – Doppeltippen
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        view.addInteraction(pencilInteraction)

        // Stift/Finger-Erkennung via Gesture Recognizer
        let detector = TouchTypeGesture()
        detector.cancelsTouchesInView = false
        detector.delaysTouchesBegan = false
        detector.onPencil = { [weak self] in self?.onPencilDetected?() }
        detector.onFinger = { [weak self] in self?.onFingerDetected?() }
        scrollView.addGestureRecognizer(detector)
        touchDetector = detector
    }

    func update(rootView: AnyView) {
        hostingController.rootView = rootView
    }

    // MARK: - UIPencilInteractionDelegate

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        onPencilDoubleTap?()
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        hostingController.view
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        zoomScaleDidChange?(scrollView.zoomScale)
        let offsetX = max((scrollView.bounds.width  - scrollView.contentSize.width)  * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        hostingController.view.center = CGPoint(
            x: scrollView.contentSize.width  * 0.5 + offsetX,
            y: scrollView.contentSize.height * 0.5 + offsetY
        )
    }
}

// MARK: - Touch-Typ-Erkenner

/// Beobachtet Berührungstypen, ohne Gesten zu konsumieren.
final class TouchTypeGesture: UIGestureRecognizer {
    var onPencil: (() -> Void)?
    var onFinger: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            if touch.type == .pencil {
                onPencil?()
            } else if touch.type == .direct {
                onFinger?()
            }
        }
        state = .failed
    }
}
#endif
