import UIKit

/**
 This function is used to set the `UINavigationBar`'s titleView property
 */
func setTitle(title:String, subtitle:String) -> UIView {
    //Create a label programmatically and give it its property's
    let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 0)) //x, y, width, height where y is to offset from the view center
    titleLabel.backgroundColor = UIColor.clear
    titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
    titleLabel.text = title
    titleLabel.sizeToFit()

    //Create a label for the Subtitle
    let subtitleLabel = UILabel(frame: CGRect(x: 0, y: 18, width: 0, height: 0))
    subtitleLabel.backgroundColor = UIColor.clear
    subtitleLabel.textColor = UIColor.secondaryLabel
    subtitleLabel.font = UIFont.systemFont(ofSize: 12)
    subtitleLabel.text = subtitle
    subtitleLabel.sizeToFit()

    // Create a view and add titleLabel and subtitleLabel as subviews setting
    let titleView = UIView(frame: CGRect(x: 0, y: 0, width: max(titleLabel.frame.size.width, subtitleLabel.frame.size.width), height: 30))

    // Center title or subtitle on screen (depending on which is larger)
    if titleLabel.frame.width >= subtitleLabel.frame.width {
        var adjustment = subtitleLabel.frame
        adjustment.origin.x = titleView.frame.origin.x + (titleView.frame.width/2) - (subtitleLabel.frame.width/2)
        subtitleLabel.frame = adjustment
    } else {
        var adjustment = titleLabel.frame
        adjustment.origin.x = titleView.frame.origin.x + (titleView.frame.width/2) - (titleLabel.frame.width/2)
        titleLabel.frame = adjustment
    }

    titleView.addSubview(titleLabel)
    titleView.addSubview(subtitleLabel)

    return titleView
}

