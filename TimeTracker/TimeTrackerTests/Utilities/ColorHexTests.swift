import Testing
import SwiftUI
import AppKit
@testable import TimeTracker

@MainActor
struct ColorHexTests {

    private func rgbComponents(of color: Color) -> (red: Double, green: Double, blue: Double) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB)!
        return (
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent)
        )
    }

    @Test func pureRed() {
        let color = Color(hex: "FF0000")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 1.0) < 0.01)
        #expect(abs(rgb.green - 0.0) < 0.01)
        #expect(abs(rgb.blue - 0.0) < 0.01)
    }

    @Test func pureGreen() {
        let color = Color(hex: "00FF00")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 0.0) < 0.01)
        #expect(abs(rgb.green - 1.0) < 0.01)
        #expect(abs(rgb.blue - 0.0) < 0.01)
    }

    @Test func pureBlue() {
        let color = Color(hex: "0000FF")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 0.0) < 0.01)
        #expect(abs(rgb.green - 0.0) < 0.01)
        #expect(abs(rgb.blue - 1.0) < 0.01)
    }

    @Test func customColor() {
        let color = Color(hex: "FF5733")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 1.0) < 0.01)
        #expect(abs(rgb.green - 87.0 / 255.0) < 0.01)
        #expect(abs(rgb.blue - 51.0 / 255.0) < 0.01)
    }

    @Test func hexWithHashPrefix() {
        let color = Color(hex: "#FF0000")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 1.0) < 0.01)
        #expect(abs(rgb.green - 0.0) < 0.01)
        #expect(abs(rgb.blue - 0.0) < 0.01)
    }

    @Test func lowercaseHex() {
        let color = Color(hex: "ff5733")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 1.0) < 0.01)
        #expect(abs(rgb.green - 87.0 / 255.0) < 0.01)
        #expect(abs(rgb.blue - 51.0 / 255.0) < 0.01)
    }

    @Test func black() {
        let color = Color(hex: "000000")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 0.0) < 0.01)
        #expect(abs(rgb.green - 0.0) < 0.01)
        #expect(abs(rgb.blue - 0.0) < 0.01)
    }

    @Test func white() {
        let color = Color(hex: "FFFFFF")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 1.0) < 0.01)
        #expect(abs(rgb.green - 1.0) < 0.01)
        #expect(abs(rgb.blue - 1.0) < 0.01)
    }

    @Test func invalidLengthDefaultsToWhite() {
        let color = Color(hex: "FFF")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 1.0) < 0.01)
        #expect(abs(rgb.green - 1.0) < 0.01)
        #expect(abs(rgb.blue - 1.0) < 0.01)
    }

    @Test func emptyStringDefaultsToWhite() {
        let color = Color(hex: "")
        let rgb = rgbComponents(of: color)
        #expect(abs(rgb.red - 1.0) < 0.01)
        #expect(abs(rgb.green - 1.0) < 0.01)
        #expect(abs(rgb.blue - 1.0) < 0.01)
    }
}
