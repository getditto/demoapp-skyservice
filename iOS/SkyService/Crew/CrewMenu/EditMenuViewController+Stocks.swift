//
//  EditMenuViewController+Stocks.swift
//  SkyService
//
//  Created by kndoshn on 2021/05/05.
//

import Eureka
import RxSwift

extension EditMenuItemViewController {

    func setupStocksSection() {
        form
            +++ Section("Stocks")
            <<< StepperRow("totalCount") {
                $0.title = "Total"
            }.onChange({ [weak self] row in
                guard let self = self else { return }
                if let value = row.value {
                    Task {
                        await DataService.shared.updateMenuItemTotalCount(id: self.menuItemId, value: value)
                    }
                }
            }).cellUpdate({ (cell, row) in
                if let value = row.value {
                    cell.valueLabel.text = "\(Int(value))"
                }
            })
            <<< IntRow("usedCount") {
                $0.title = "Used"
                $0.disabled = true
            }
            <<< IntRow("remainsCount") {
                $0.title = "Remains"
                $0.disabled = true
            }

        DataService.shared
            .menuItemById$(menuItemId)
            .distinctUntilChanged()
            .bind { [weak self] item in
                guard let self = self, let item = item else { return }
                guard let totalCountRow = self.form.rowBy(tag: "totalCount") as? StepperRow else { return }
                guard let usedCountRow = self.form.rowBy(tag: "usedCount") as? IntRow else { return }
                guard let remainsCountRow = self.form.rowBy(tag: "remainsCount") as? IntRow else { return }

                if let totalCount = item.totalCount {
                    self.form.setValues(["totalCount": Double(totalCount)])
                    totalCountRow.reload()

                    let used = item.usedCount ?? 0
                    let remains = totalCount - used
                    self.form.setValues(["remainsCount": remains])
                    remainsCountRow.reload()
                }
                if let usedCount = item.usedCount {
                    self.form.setValues(["usedCount": usedCount])
                    usedCountRow.reload()
                }
            }
            .disposed(by: disposeBag)
    }
}
