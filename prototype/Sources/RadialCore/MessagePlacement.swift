import Foundation

/// A message card in the ring's lower third, with an optional Back control below.
enum MessagePlacement {
    struct Result {
        let card: Rect
        let back: Rect?
    }

    /// Smallest ring that keeps the card's center in the lower third and fits
    /// every corner of the card and Back control inside the padded circle.
    static func minimumRadius(card: Size, back: Size?, spacing: Double, padding: Double) -> Double {
        let fraction = 1.0 / 3
        let coefficient = 1 - fraction * fraction
        func radius(halfWidth: Double, bottom: Double) -> Double {
            (padding + fraction * bottom + hypot(bottom + fraction * padding,
                sqrt(coefficient) * halfWidth)) / coefficient
        }
        let cardRadius = radius(halfWidth: card.width / 2, bottom: card.height / 2)
        guard let back else { return cardRadius }
        return max(cardRadius, radius(halfWidth: back.width / 2,
                                      bottom: card.height / 2 + spacing + back.height))
    }

    static func make(card: Size, back: Size?, radius: Double, spacing: Double, padding: Double) -> Result? {
        guard card.isValid, back?.isValid ?? true,
              [radius, spacing, padding].allSatisfy(\.isFinite), spacing > 0, padding > 0,
              radius > padding else { return nil }
        let usable = radius - padding
        func bottomLimit(width: Double) -> Double? {
            let fraction = width / (2 * usable)
            guard fraction <= 1 else { return nil }
            return usable * sqrt(1 - fraction * fraction)
        }
        guard let cardBottom = bottomLimit(width: card.width) else { return nil }
        var maximumCenter = cardBottom - card.height / 2
        if let back {
            guard let backBottom = bottomLimit(width: back.width) else { return nil }
            maximumCenter = min(maximumCenter, backBottom - card.height / 2 - spacing - back.height)
        }
        // Aim for the middle of the lower third. Taller or wider content moves
        // upward only far enough to keep its complete bounds inside the ring.
        let centerY = min(2 * radius / 3, maximumCenter)
        guard centerY.isFinite, centerY >= radius / 3 - 1e-8 else { return nil }
        let bounds = Rect(x: -card.width / 2, y: centerY - card.height / 2,
                          width: card.width, height: card.height)
        return Result(card: bounds, back: back.map {
            Rect(x: -$0.width / 2, y: bounds.y + bounds.height + spacing,
                 width: $0.width, height: $0.height)
        })
    }
}
