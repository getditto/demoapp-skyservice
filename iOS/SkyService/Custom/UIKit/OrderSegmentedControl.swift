import UIKit
import BetterSegmentedControl

class OrderSegmentedControl: BetterSegmentedControl {

    init() {
        let segmentLabels = Order.Status.allCases
            .map({ LabelSegment(text: $0.segmentedControlTitle,
                                normalBackgroundColor: UIColor.secondarySystemBackground,
                                normalTextColor: .secondaryLabel,
                                selectedBackgroundColor: $0.tintColor,
                                selectedTextColor: $0.segmentedControlTextColor )})
        super.init(frame: .zero, segments: segmentLabels, options: [.cornerRadius(8), .backgroundColor(.secondarySystemBackground)])
        self.animationDuration = 0.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var orderId: String?

    var status: Order.Status? {
        didSet {
            guard let status = status else {
                return
            }
            guard status != oldValue else { return }
            guard let index = Order.Status.allCases.firstIndex(where: { $0 == status }) else { return }
            self.setIndex(index)
        }
    }


}
