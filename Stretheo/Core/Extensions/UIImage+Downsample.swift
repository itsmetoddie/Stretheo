//
//  UIImage+Downsample.swift
//  Stretheo
//

import UIKit

extension UIImage {
    /// Returns an image scaled for on-screen display (avoids decoding full resolution in small frames).
    func downsampledForDisplay(pointSize: CGFloat, scale: CGFloat = UITraitCollection.current.displayScale) -> UIImage {
        let maxPixel = pointSize * scale
        let longest = max(size.width, size.height)
        guard longest > maxPixel, longest > 0 else { return self }

        let ratio = maxPixel / longest
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRenderer(size: target)
        return format.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
