import UIKit
import Cartography
import RxSwift
import RxDataSources

/**
 Max:
 This ViewController doesn't use RxDataSource
 I couldn't figure out how to enable drag-reordering
 */
class CategoriesViewController: UIViewController {

    var disposeBag = DisposeBag()

    var dataSource: RxTableViewSectionedAnimatedDataSource<SectionOfCategories>!
    let tableView = UITableView()
    var categories: [Category] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        title = "Manage Categories"

        constrain(tableView) { tableView in
            tableView.fillToSuperView()
        }

        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true

        let newCategoryBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        navigationItem.rightBarButtonItem = newCategoryBarButton

        dataSource = RxTableViewSectionedAnimatedDataSource<SectionOfCategories>(configureCell: { (dataSource, tableView, indexPath, category) -> UITableViewCell in
            let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
            cell.selectionStyle = .blue
            cell.textLabel?.text = category.name
            cell.detailTextLabel?.text = category.details
            return cell
        })

        dataSource.animationConfiguration = AnimationConfiguration(insertAnimation: .automatic, reloadAnimation: .none, deleteAnimation: .automatic)

        dataSource.canEditRowAtIndexPath = { dataSource, indexPath in
          return true
        }

        dataSource.canMoveRowAtIndexPath = { dataSource, indexPath in
          return true
        }


        DataService.shared.categories$()
            .map({ [SectionOfCategories(items: $0)] })
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        tableView
            .rx
            .itemMoved
            .bind { event in
                let destinationIndexPath = event.destinationIndex
                let sourceIndexPath = event.sourceIndex
                guard sourceIndexPath != destinationIndexPath else { return }
                let categories = self.dataSource.sectionModels[sourceIndexPath.section].items.sorted(by: { $0.ordinal < $1.ordinal })
                let category = categories[sourceIndexPath.row]
                let categoryId = category.id
                let sourceIndex: Int = sourceIndexPath.row
                let destinationIndex: Int = destinationIndexPath.row
                let differentSection = (sourceIndexPath.section != destinationIndexPath.section)
                let newOrdinal = calculateOrdinal(sourceIndex: sourceIndex, destinationIndex: destinationIndex, items: categories, differentSection: differentSection)
                DataService.shared.updateCategoryOrdinal(id: categoryId, newOrdinal: newOrdinal)
            }
            .disposed(by: disposeBag)

        tableView
            .rx
            .modelDeleted(Category.self)
            .map({ $0.id })
            .bind { categoryId in
                DataService.shared.deleteCategory(id: categoryId)
            }
            .disposed(by: disposeBag)

        tableView
            .rx
            .modelSelected(Category.self)
            .bind { [weak self] category in
                guard let `self` = self else { return }
                let editVC = EditCategoryViewController(categoryId: category.id)
                let nav = UINavigationController(rootViewController: editVC)
                self.present(nav, animated: true, completion: nil)
            }
            .disposed(by: disposeBag)

        newCategoryBarButton
            .rx
            .tap
            .bind { [unowned self] in
                let nav = UINavigationController(rootViewController: EditCategoryViewController())
                self.present(nav, animated: true, completion: nil)
            }
            .disposed(by: disposeBag)
    }
    
    deinit {
        disposeBag = DisposeBag()
    }
}
