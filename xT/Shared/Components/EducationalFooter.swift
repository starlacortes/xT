//
//  EducationalFooter.swift
//  xT
//
//  Marks a surface as general educational content rather than a statement about
//  this user.
//
//  Everywhere else, xT reports only what it recorded or modelled from the user's
//  own data. The body-system detail screens are the exception: they describe what
//  typically happens on hormone therapy, drawn from population data, and they are
//  the one place the app discusses interventions at all. That difference has to be
//  visible, or a general statement reads as a statement about the reader.
//

import SwiftUI

struct EducationalFooter: View {
    /// Tint to match the surrounding section palette.
    var accent: Color = Theme.Colors.accent

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(accent)
                .padding(.top, 1)

            Text("General information about hormone therapy, based on population data. Not medical advice, and not specific to you.")
                .font(Theme.Fonts.micro)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
}

#if DEBUG
#Preview {
    EducationalFooter()
}
#endif
