//
//  ScrollBlurModifier.swift
//  xT
//
//  Created by Cline on 4/6/2026.
//  Scroll blur effect modifier for Liquid Glass design
//

import SwiftUI

/// Scroll blur modifier that adds a blur effect under the notch when scrolling up
struct ScrollBlurModifier: ViewModifier {
    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named("scroll")).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollOffset = offset
                }
            }
            .overlay(
                VisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
                    .opacity(scrollOffset < -20 ? 1 : 0)
                    .frame(height: scrollOffset < -20 ? 80 : 0)
                    .clipped()
                    .ignoresSafeArea(),
                alignment: .top
            )
    }
}

/// Helper for scroll offset tracking
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// UIKit VisualEffectView wrapper for SwiftUI
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

/// Extension for easy use
extension View {
    func scrollBlurEffect() -> some View {
        self.modifier(ScrollBlurModifier())
    }
}