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
                GlassBlurOverlay(scrollOffset: scrollOffset),
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

// MARK: - Glass Blur Overlay (iOS 26 Liquid Glass with fallback)

private struct GlassBlurOverlay: View {
    let scrollOffset: CGFloat
    
    var body: some View {
        if #available(iOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.tint(.black.opacity(0.3)), in: .rect())
                .opacity(scrollOffset < -20 ? 1 : 0)
                .frame(height: scrollOffset < -20 ? 80 : 0)
                .clipped()
                .ignoresSafeArea()
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(scrollOffset < -20 ? 1 : 0)
                .frame(height: scrollOffset < -20 ? 80 : 0)
                .clipped()
                .ignoresSafeArea()
        }
    }
}
