import Foundation
import SwiftUI

public struct CategoryStyle: Codable, Hashable {
    public var name: String
    public var icon: String
    public var colorHex: String

    public init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    public var color: Color { Color(hex: colorHex) ?? .gray }
}

public enum CategoryPalette {
    public static let colors: [String] = [
        "#0A84FF", // azul
        "#FF453A", // rojo
        "#30D158", // verde
        "#BF5AF2", // morado
        "#FF9F0A", // naranja
        "#5E5CE6", // índigo
        "#FF375F", // rosa
        "#64D2FF", // cyan
        "#FFD60A", // amarillo
        "#AC8E68", // marrón
    ]

    public static let icons: [String] = [
        "🏠","👤","💼","💊","🐾","🍴","🚗","📚",
        "🌱","💡","✨","🎯","🧹","🏃","🛒","💰"
    ]
}

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
