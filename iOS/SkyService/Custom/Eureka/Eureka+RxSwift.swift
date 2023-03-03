import Foundation
import Eureka
import RxSwift
import RxCocoa

extension RowOf: ReactiveCompatible {}

extension Reactive where Base: RowType, Base: BaseRow {
    var value: ControlProperty<Base.Cell.Value?> {
        let source = Observable<Base.Cell.Value?>.create { observer in
            self.base.onChange { row in
                observer.onNext(row.value)
                row.updateCell()
            }
            return Disposables.create()
        }
        let bindingObserver = Binder(self.base) { (row, value) in
            row.value = value
        }
        return ControlProperty(values: source, valueSink: bindingObserver)
    }
}
