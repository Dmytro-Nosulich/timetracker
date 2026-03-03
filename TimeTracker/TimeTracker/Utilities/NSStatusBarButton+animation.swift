//
//  NSStatusBarButton+animation.swift
//  TimeTracker
//
//  Created by Pavlo Ignatov on 02.03.2026.
//

import AppKit

extension NSStatusBarButton {
    @MainActor
    func startPulseAnimation() {
        wantsLayer = true

        // Only add if not already animating
        guard layer?.animation(forKey: "pulse") == nil else { return }

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 2.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        layer?.add(pulse, forKey: "pulse")
    }
    
    @MainActor
    func stopPulseAnimation() {
        layer?.removeAllAnimations()
    }
}
