//
//  ScrollBlurModifier.swift
//  xT
//
//  Created by Cline on 4/6/2026.
//  Scroll blur effect modifier for Liquid Glass design
//

import SwiftUI

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
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(scrollOffset < -20 ? 1 : 0)
                    .frame(height: scrollOffset < -20 ? 80 : 0)
                    .clipped()
                    .ignoresSafeArea(),
                alignment: .top
            )
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func scrollBlurEffect() -> some View {
        self.modifier(ScrollBlurModifier())
    }
}

// MARK: - Reusable Scroll Offset Reader

/// A reusable modifier that reads the scroll offset of a view in a named
/// coordinate space and writes it to a binding. Eliminates the
/// GeometryReader / .preference / .onPreferenceChange boilerplate
/// required by every scroll-tracking view.
struct ScrollOffsetReader: ViewModifier {
    let coordinateSpace: String
    @Binding var offset: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named(coordinateSpace)).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { newValue in
                offset = newValue
            }
    }
}

extension View {
    func readScrollOffset(in coordinateSpace: String, binding: Binding<CGFloat>) -> some View {
        modifier(ScrollOffsetReader(coordinateSpace: coordinateSpace, offset: binding))
    }
}
