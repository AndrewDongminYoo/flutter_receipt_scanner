import CoreImage
import UIKit

/// Custom 4-handle perspective crop editor.
///
/// Faithful port of RN `RNCropEditorViewController` (ADR-004). The real-device
/// fixes are load-bearing and must NOT be "modernized":
///   - `UIButton` + `.touchUpInside`, never `UIBarButtonItem` (target-action
///     silently fails in some modal presentation paths).
///   - Button bar anchored to `view.bottomAnchor` − 34, not the safe-area guide
///     (which can report 0, dropping the bar into the home-indicator zone).
///   - The four handles are added BEFORE the button bar so UIKit's reverse-order
///     hit-testing gives the bar priority near the image bottom.
///
/// Corners are kept in CIImage coordinate space (origin bottom-left, Y up).
final class CropEditorViewController: UIViewController {
    private enum Corner {
        static let topLeft = 0
        static let topRight = 1
        static let bottomRight = 2
        static let bottomLeft = 3
    }

    private static let handleRadius: CGFloat = 16
    private static let detectedCropExpansionFactor: CGFloat = 1.12

    private let sourceImage: UIImage
    private var corners: [CGPoint]
    private var completion: ((CGImage?) -> Void)?

    private let imageView = UIImageView()
    private var handles: [UIView] = []
    private let overlayLayer = CAShapeLayer()

    /// - Parameters:
    ///   - image: the picked photo (orientation preserved).
    ///   - corners: detected corners in CIImage space, or nil for a 10% inset default.
    ///   - completion: called once with the cropped CGImage, or nil on cancel.
    init(image: UIImage, corners: [CGPoint]?, completion: @escaping (CGImage?) -> Void) {
        sourceImage = image
        self.completion = completion

        let width = image.size.width
        let height = image.size.height
        if let corners, corners.count == 4 {
            self.corners = Self.expandedCorners(corners, imageSize: image.size)
        } else {
            // Vision found nothing. A 10% inset is a better start than full-image
            // edges: receipts rarely fill the frame. CIImage space: origin
            // bottom-left, Y up.
            let d: CGFloat = 0.1
            self.corners = [
                CGPoint(x: width * d, y: height * (1 - d)), // topLeft
                CGPoint(x: width * (1 - d), y: height * (1 - d)), // topRight
                CGPoint(x: width * (1 - d), y: height * d), // bottomRight
                CGPoint(x: width * d, y: height * d), // bottomLeft
            ]
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func expandedCorners(_ corners: [CGPoint], imageSize: CGSize) -> [CGPoint] {
        var center = CGPoint.zero
        for point in corners {
            center.x += point.x
            center.y += point.y
        }
        center.x /= CGFloat(corners.count)
        center.y /= CGFloat(corners.count)

        return corners.map { point in
            let expanded = CGPoint(
                x: center.x + (point.x - center.x) * detectedCropExpansionFactor,
                y: center.y + (point.y - center.y) * detectedCropExpansionFactor
            )
            return CGPoint(
                x: max(0, min(imageSize.width, expanded.x)),
                y: max(0, min(imageSize.height, expanded.y))
            )
        }
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        imageView.image = sourceImage
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        let accent = UIColor.systemBlue

        overlayLayer.fillColor = accent.withAlphaComponent(0.2).cgColor
        overlayLayer.strokeColor = accent.withAlphaComponent(0.9).cgColor
        overlayLayer.lineWidth = 2
        view.layer.addSublayer(overlayLayer)

        // Handles are added BEFORE the button bar so hitTest (reverse subview order)
        // checks the bar first — handles near the image bottom must not absorb
        // button taps (ADR-004 D2).
        for index in 0 ..< 4 {
            let handle = UIView(frame: CGRect(
                x: 0, y: 0, width: Self.handleRadius * 2, height: Self.handleRadius * 2
            ))
            handle.backgroundColor = .white
            handle.layer.cornerRadius = Self.handleRadius
            handle.layer.borderColor = accent.cgColor
            handle.layer.borderWidth = 2
            handle.tag = index
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            handle.addGestureRecognizer(pan)
            view.addSubview(handle)
            handles.append(handle)
        }

        let instructionBubble = UIView()
        instructionBubble.translatesAutoresizingMaskIntoConstraints = false
        instructionBubble.backgroundColor = UIColor(white: 0, alpha: 0.62)
        instructionBubble.layer.cornerRadius = 8
        instructionBubble.layer.masksToBounds = true
        instructionBubble.isUserInteractionEnabled = false

        let instructionLabel = UILabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = Self.localized(
            "FlutterReceiptScanner_cropInstruction",
            "Drag the corners to frame the document"
        )
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0

        instructionBubble.addSubview(instructionLabel)
        view.addSubview(instructionBubble)

        // Plain UIView + UIButton bar — added LAST for highest hit-test priority.
        // UIBarButtonItem target-action can silently fail in modal presentation
        // paths; UIButton fires .touchUpInside directly (ADR-004 D1).
        let buttonBar = UIView()
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.backgroundColor = UIColor(white: 0.12, alpha: 1)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(
            Self.localized("FlutterReceiptScanner_cancelButton", "Cancel"),
            for: .normal
        )
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle(
            Self.localized("FlutterReceiptScanner_confirmButton", "Use Photo"),
            for: .normal
        )
        confirmButton.setTitleColor(.systemBlue, for: .normal)
        confirmButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)

        buttonBar.addSubview(cancelButton)
        buttonBar.addSubview(confirmButton)
        view.addSubview(buttonBar)

        // Anchor to view.bottomAnchor − 34 (home-indicator zone height on Face ID
        // devices). safeAreaLayoutGuide.bottomAnchor can report 0 in some modal
        // presentation paths, pushing the bar into the system gesture zone.
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: buttonBar.topAnchor),

            instructionBubble.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12
            ),
            instructionBubble.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor, constant: 20
            ),
            instructionBubble.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor, constant: -20
            ),
            instructionBubble.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            instructionLabel.topAnchor.constraint(equalTo: instructionBubble.topAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(
                equalTo: instructionBubble.leadingAnchor, constant: 12
            ),
            instructionLabel.trailingAnchor.constraint(
                equalTo: instructionBubble.trailingAnchor, constant: -12
            ),
            instructionLabel.bottomAnchor.constraint(
                equalTo: instructionBubble.bottomAnchor, constant: -8
            ),

            buttonBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -34),
            buttonBar.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.leadingAnchor.constraint(equalTo: buttonBar.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),

            confirmButton.trailingAnchor.constraint(equalTo: buttonBar.trailingAnchor, constant: -20),
            confirmButton.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        overlayLayer.frame = view.bounds
        updateHandlePositions()
        updateOverlayPath()
    }

    // MARK: - Coordinate mapping (aspect-fit letterbox)

    private var imageRectInView: CGRect {
        let ivSize = imageView.bounds.size
        let imgSize = sourceImage.size
        guard ivSize.width > 0, ivSize.height > 0, imgSize.height > 0 else { return .zero }
        let ivAspect = ivSize.width / ivSize.height
        let imgAspect = imgSize.width / imgSize.height
        if ivAspect > imgAspect {
            let h = ivSize.height
            let w = h * imgAspect
            return CGRect(
                x: (ivSize.width - w) / 2 + imageView.frame.origin.x,
                y: imageView.frame.origin.y, width: w, height: h
            )
        } else {
            let w = ivSize.width
            let h = w / imgAspect
            return CGRect(
                x: imageView.frame.origin.x,
                y: (ivSize.height - h) / 2 + imageView.frame.origin.y, width: w, height: h
            )
        }
    }

    private func viewPoint(fromCI ci: CGPoint) -> CGPoint {
        let rect = imageRectInView
        let x = rect.origin.x + (ci.x / sourceImage.size.width) * rect.size.width
        let y = rect.origin.y + (1 - ci.y / sourceImage.size.height) * rect.size.height
        return CGPoint(x: x, y: y)
    }

    private func ciPoint(fromView view: CGPoint) -> CGPoint {
        let rect = imageRectInView
        guard rect.width > 0, rect.height > 0 else { return .zero }
        let ciX = ((view.x - rect.origin.x) / rect.size.width) * sourceImage.size.width
        let ciY = (1 - (view.y - rect.origin.y) / rect.size.height) * sourceImage.size.height
        return CGPoint(x: ciX, y: ciY)
    }

    private func updateHandlePositions() {
        for index in 0 ..< min(4, handles.count) {
            handles[index].center = viewPoint(fromCI: corners[index])
        }
    }

    private func updateOverlayPath() {
        guard handles.count >= 4 else { return }
        let path = UIBezierPath()
        path.move(to: handles[Corner.topLeft].center)
        path.addLine(to: handles[Corner.topRight].center)
        path.addLine(to: handles[Corner.bottomRight].center)
        path.addLine(to: handles[Corner.bottomLeft].center)
        path.close()
        overlayLayer.path = path.cgPath
    }

    // MARK: - Interaction

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let handle = pan.view else { return }
        let translation = pan.translation(in: view)
        var newCenter = CGPoint(
            x: handle.center.x + translation.x,
            y: handle.center.y + translation.y
        )
        let rect = imageRectInView
        newCenter.x = max(rect.origin.x, min(rect.origin.x + rect.size.width, newCenter.x))
        newCenter.y = max(rect.origin.y, min(rect.origin.y + rect.size.height, newCenter.y))

        handle.center = newCenter
        corners[handle.tag] = ciPoint(fromView: newCenter)
        pan.setTranslation(.zero, in: view)
        updateOverlayPath()
    }

    @objc private func handleCancel() {
        let completion = self.completion
        self.completion = nil
        dismiss(animated: true) {
            completion?(nil)
        }
    }

    @objc private func handleConfirm() {
        let corners = self.corners
        let sourceImage = self.sourceImage
        // Nil the completion before the async render so a later dismiss/cancel
        // cannot double-invoke it.
        let completion = self.completion
        self.completion = nil

        // Dismiss immediately so the tap feels responsive; render on a background
        // queue.
        dismiss(animated: true) {
            DispatchQueue.global(qos: .default).async {
                let cropped = QuadDetector.perspectiveCorrected(sourceImage, corners: corners)
                completion?(cropped)
            }
        }
    }

    // MARK: - Localization

    private static func localized(_ key: String, _ fallback: String) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
    }
}
