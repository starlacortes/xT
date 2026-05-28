//
//  WelcomeTourView.swift
//  xT
//
//  Created by Cline on 3/22/2026.
//  Welcome tour for first-time users
//

import SwiftUI

struct WelcomeTourView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let tourSteps = [
        WelcomeStep(
            title: "Welcome to xT!",
            description: "Your personal medication tracker and hormone level monitor.",
            icon: "heart.fill",
            color: .pink
        ),
        WelcomeStep(
            title: "Track Your Medication",
            description: "Easily record when you take your medication and monitor your schedule.",
            icon: "pills.fill",
            color: .blue
        ),
        WelcomeStep(
            title: "Monitor Your Progress",
            description: "View estimated hormone levels and track your progress over time.",
            icon: "chart.line.uptrend.xyaxis",
            color: .green
        ),
        WelcomeStep(
            title: "Customize Your Profile",
            description: "Personalize your experience with profile settings and preferences.",
            icon: "person.fill",
            color: .purple
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<tourSteps.count, id: \.self) { index in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(index == currentStep ? .blue : .gray.opacity(0.3))
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.spring(), value: currentStep)
                }
            }
            .padding(.top, 16)

            Spacer()

            // Step content
            VStack(spacing: 24) {
                Image(systemName: tourSteps[currentStep].icon)
                    .font(.system(size: 64))
                    .foregroundColor(tourSteps[currentStep].color)
                    .padding()
                    .background(tourSteps[currentStep].color.opacity(0.1))
                    .clipShape(Circle())
                    .padding(.bottom, 16)

                Text(tourSteps[currentStep].title)
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(tourSteps[currentStep].description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding()
            .transition(.opacity.combined(with: .scale))

            Spacer()

            // Navigation buttons
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button(action: {
                        withAnimation {
                            currentStep -= 1
                        }
                    }) {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                    }
                }

                if currentStep < tourSteps.count - 1 {
                    Button(action: {
                        withAnimation {
                            currentStep += 1
                        }
                    }) {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

struct WelcomeStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

#Preview {
    WelcomeTourView()
}