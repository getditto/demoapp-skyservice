import DittoSwift

struct WorkspaceId: CustomStringConvertible, ExpressibleByStringLiteral {

    static var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy"
        return dateFormatter
    }
    private static let delimiter: String = "::"

    var description: String {
        return "\(Self.dateFormatter.string(from: self.departureDate))\(Self.delimiter)\(self.flightNumber)"
    }

    var departureDate: Date
    var flightNumber: String

    var id: String

    init(departureDate: Date, flightNumber: String) {
        self.id = "\(Self.dateFormatter.string(from: departureDate))::\(flightNumber)"
        self.departureDate = departureDate
        self.flightNumber = flightNumber
    }

    init(stringLiteral value: StringLiteralType) {
        self.id = value
        let parts = value.components(separatedBy: Self.delimiter)
        self.departureDate = Self.dateFormatter.date(from: parts[0])!
        self.flightNumber = parts[1]
    }
}
