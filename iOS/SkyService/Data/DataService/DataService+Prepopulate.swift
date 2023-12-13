import RxSwift
import DittoSwift

extension DataService {

    func deleteCategoriesAndMenu() async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else { return }
        
        //Use Write Transactions when available in DQL
        do {
            let categoryRresults = try await ditto.store.execute(query: "SELECT * FROM categories WHERE workspaceId = :workspaceId", arguments: ["workspaceId": workspaceId]).items
            
            for result in categoryRresults {
                try await self.ditto.store.execute(query: "UPDATE categories SET deleted = :deleted WHERE _id = :id", arguments: ["deleted": true, "id": result.value["_id"] as Any?])
            }
            
            let menuResults = try await ditto.store.execute(query: "SELECT * FROM menuItems WHERE workspaceId = :workspaceId", arguments: ["workspaceId": workspaceId]).items
            
            for result in menuResults {
                try await self.ditto.store.execute(query: "UPDATE menuItems SET deleted = :deleted WHERE _id = :id", arguments: ["deleted": true, "id": result.value["_id"] as Any?])
            }

        } catch {
            print("Error: \(error)")
        }

    }

    func prepopulateMenuItems() async {
        guard let workspaceId = UserDefaults.standard.workspaceId?.description else { return }

        let categoryData: [[String: Any]] = [
            [
                "id": "appetizers" + workspaceId,
                "name": "Appetizers",
                "workspaceId": workspaceId,
                "details": "Get started with some early bites.",
                "ordinal": 0.12,
                "isCrewOnly": false
            ],
            [
                "id": "snacks" + workspaceId,
                "name": "Snacks",
                "workspaceId": workspaceId,
                "details": "Not so hungry? Pass the time with some lovely snacks.",
                "ordinal": 1.1,
                "isCrewOnly": false
            ],
            [
                "id": "main-courses" + workspaceId,
                "name": "Main Courses",
                "workspaceId": workspaceId,
                "details": "Land with a full stomach.",
                "ordinal": 2.3,
                "isCrewOnly": false
            ],
            [
                "id": "desserts" + workspaceId,
                "name": "Desserts",
                "workspaceId": workspaceId,
                "details": "Try our world class sweets.",
                "ordinal": 3.0301,
                "isCrewOnly": false
            ],
            [
                "id": "alcoholic-drinks" + workspaceId,
                "name": "Alcoholic Beverages",
                "workspaceId": workspaceId,
                "details": "Enjoy a relaxing beer, wine or cocktail",
                "ordinal": 4.2,
                "isCrewOnly": false
            ],
            [
                "id": "non-alcoholic-drinks" + workspaceId,
                "name": "Sodas and Drinks",
                "workspaceId": workspaceId,
                "details": "Enjoy sodas, carbonated water, coffees, teas and more",
                "ordinal": 6.2,
                "isCrewOnly": false
            ]
        ]

        let menuItemsData: [[String: Any?]] = [
            [
                "name": "Garden Salad",
                "price": 4.00,
                "categoryId": "appetizers" + workspaceId,
                "ordinal": 0.1,
                "workspaceId": workspaceId,
                "details": "A simple light garden salad with red wine vinagrette.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Focaccia Bread and Olive Oil",
                "price": 4.00,
                "categoryId": "appetizers" + workspaceId,
                "ordinal": 1.1,
                "workspaceId": workspaceId,
                "details": "Also comes with a side of balsamic vinagrette.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Chips",
                "price": 4.00,
                "categoryId": "snacks" + workspaceId,
                "ordinal": 0.1,
                "workspaceId": workspaceId,
                "details": "Crispy sea salted potato chips. 120 calories.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Chocolate Chip Cookies",
                "price": 4.00,
                "categoryId": "snacks" + workspaceId,
                "ordinal": 1.1,
                "workspaceId": workspaceId,
                "details": "Bite size chocolate cookies. 11 calories each.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "General Snackbox",
                "price": 10.00,
                "ordinal": 2.3,
                "categoryId": "snacks" + workspaceId,
                "workspaceId": workspaceId,
                "details": "Cheese, dates, nuts, and dried berries",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Turkey Sandwich",
                "price": 14.25,
                "ordinal": 0.12,
                "categoryId": "main-courses" + workspaceId,
                "workspaceId": workspaceId,
                "details": "Turkey, lettuce, mustard, mayonaise sandwich warmed.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Curry Chicken",
                "price": 12.00,
                "ordinal": 1.22,
                "categoryId": "main-courses" + workspaceId,
                "workspaceId": workspaceId,
                "details": "Cold fresh curry and sweet potato chicken with fork and knife.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Roast Beef Sandwich",
                "price": 13.00,
                "categoryId": "main-courses" + workspaceId,
                "ordinal": 2.15,
                "workspaceId": workspaceId,
                "details": "Roast beef, lettuce, mustard, mayonaise sandwich warmed.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Vegan Spaghetti",
                "price": 12.50,
                "categoryId": "main-courses" + workspaceId,
                "ordinal": 3.15,
                "workspaceId": workspaceId,
                "details": "Spaghetti and vegan meatballs. Hot and comes with a side of grated parmesan cheese.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            // desserts
            [
                "name": "Mochi",
                "price": 12.50,
                "categoryId": "desserts" + workspaceId,
                "ordinal": 0.1124,
                "workspaceId": workspaceId,
                "details": "Comes with strawberry, mango, or green tea flavors",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Chocolate and Vanilla Fudge",
                "price": 12.50,
                "categoryId": "desserts" + workspaceId,
                "ordinal": 1.4534,
                "workspaceId": workspaceId,
                "details": "Fudge comes hot.",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],

            // alcoholic-drinks
            [
                "name": "Brewster IPA",
                "price": 12.50,
                "categoryId": "alcoholic-drinks" + workspaceId,
                "ordinal": 0.11349224,
                "workspaceId": workspaceId,
                "details": "From Australia",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Boston Lager",
                "price": 12.50,
                "categoryId": "alcoholic-drinks" + workspaceId,
                "ordinal": 1.24543,
                "workspaceId": workspaceId,
                "details": "From Boston",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Rosé",
                "price": 12.50,
                "categoryId": "alcoholic-drinks" + workspaceId,
                "ordinal": 2.1261,
                "workspaceId": workspaceId,
                "details": "From California",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            // non-alcoholic-drinks
            [
                "name": "Coca-Cola",
                "price": 3.25,
                "categoryId": "non-alcoholic-drinks" + workspaceId,
                "ordinal": 0.00224432,
                "workspaceId": workspaceId,
                "details": "Classic or Vanilla",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Pepsi",
                "price": 6.50,
                "categoryId": "non-alcoholic-drinks" + workspaceId,
                "ordinal":  1.204,
                "workspaceId": workspaceId,
                "details": "Comes also as diet pepsi",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ],
            [
                "name": "Coffee",
                "price": 4.50,
                "categoryId": "non-alcoholic-drinks" + workspaceId,
                "ordinal": 2.39261,
                "workspaceId": workspaceId,
                "details": "With Cream or Sugar",
                "maxCartQuantityPerUser": 5,
                "createdOn": Date().isoDateString,
                "totalCount": nil,
                "usedCount": nil,
                "deleted": false
            ]
        ]

        do {
            for category in categoryData {
                let id = category["id"] as! String
                let name = category["name"] as! String
                let details = category["details"] as! String
                let ordinal = category["ordinal"] as! Double
                let workspaceId = category["workspaceId"] as! String
                let isCrewOnly = category["isCrewOnly"] as! Bool
                
                let newDoc: [String:Any] = [
                    "_id": id.toDittoID(),
                    "name": name,
                    "details": details,
                    "ordinal": ordinal,
                    "workspaceId": workspaceId,
                    "isCrewOnly": isCrewOnly,
                    "deleted": false
                ]
                
                try await self.ditto.store.execute(query: "INSERT INTO categories DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE", arguments: ["newDoc": newDoc])
            }
                
            for menuItem in menuItemsData {
                try await self.ditto.store.execute(query: "INSERT INTO menuItems DOCUMENTS (:newDoc) ON ID CONFLICT DO UPDATE", arguments: ["newDoc": menuItem])
            }

        } catch {
            print("Error \(error)")
        }
        
        
        
    }


}
