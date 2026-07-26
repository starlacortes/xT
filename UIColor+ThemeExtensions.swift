import UIKit
import SwiftUI

extension UIColor {

    static var accentSecondaryAdaptive: UIColor {
        UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return isDark
                ? UIColor(red: 0.198, green: 0.182, blue: 0.339, alpha: 1.0)
                : UIColor(red: 0.130, green: 0.116, blue: 0.287, alpha: 1.0)
        }
    }
}
