//
//  InsightRowView.swift
//  xT
//
//  Status-tinted insight row with green indicator dot.
//  Adapted from FlatInsightRow logic (insightText, statusColor).
//  Uses iOS 26 Liquid Glass background on iOS 26+.
//

import SwiftUI

struct InsightRowView: View {
    @Environment(\.medicationManager) private var medicationManager
    
    private var insightText: String {
        guard let level = medicationManager.currentHormoneLevel else {
            return "Log doses to see personalized insights."
        }
        
        let range = level.range
        let explanation = level.explanation
        
        if range.contains("Critically Low") || range.contains("Sub-Therapeutic") {
            return "Your levels are critically low — a dose review or blood test is recommended."
        } else if range.contains("Very Low") || range.contains("Below Expected") {
            return "Your levels are running low. Consider checking in with your provider."
        } else if range.contains("Slightly Below") {
            return "You're slightly below your target range. A small adjustment may help."
        } else if range.contains("On Target") || range.contains("On Track") {
            return "Great! Your hormone levels are right on target. Keep up your current schedule."
        } else if range.contains("Slightly Above") {
            return "You're slightly above your target. Monitor for any side effects."
        } else if range.contains("Very High") || range.contains("Safety Check") || range.contains("Supraphysiological") {
            return "Levels are elevated — review with your provider and consider a dose adjustment."
        } else if range.contains("High") {
            return "Levels are running high. Monitor for symptoms and check in if needed."
        } else {
            return explanation.components(separatedBy: ". ").first.map { $0.hasSuffix(".") ? $0 : "\($0)." } ?? explanation
        }
    }
    
    private var statusColor: Color {
        guard let level = medicationManager.currentHormoneLevel else {
            return Theme.Colors.accent
        }
        let range = level.range
        if range.contains("Critically") || range.contains("Safety Check") || range.contains("Sub-Therapeutic") {
            return Theme.Colors.error
        } else if range.contains("Very Low") || range.contains("Very High") || range.contains("Supraphysiological") {
            return Theme.Colors.warning
        } else if range.contains("On Target") || range.contains("On Track") {
            return Theme.Colors.success
        } else {
            return Theme.Colors.accent
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(Theme.Colors.successBrand)
                .frame(width: 5, height: 5)
                .padding(.top, 4)
            
            Text(insightText)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

#Preview {
    InsightRowView()
        .environment(\.medicationManager, MedicationManager.shared)
        .padding()
        .background(Theme.Colors.glassTint)
}