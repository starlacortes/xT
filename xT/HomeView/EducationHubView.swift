//
//  EducationHubView.swift
//  xT
//
//  Created by Cline on 3/22/2026.
//

import SwiftUI

struct EducationHubView: View {
    @Environment(\.medicationManager) private var medicationManager
    @State private var selectedMedicationForViewing: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with large flask icon and title
                VStack(spacing: 16) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                        .padding(16)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                        )

                    Text("Education Hub")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)

                    Text("Learn about your transition journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)

                // Medication Viewing Selector
                if medicationManager.selectedMedication != nil {
                    MedicationViewingSelector(selectedMedication: $selectedMedicationForViewing)
                        .padding(.horizontal, -16)
                }

                // Introspective comments based on user data
                if medicationManager.selectedMedication != nil,
                   medicationManager.selectedAdministrationMethod != nil {
                    PersonalizedInsightsView(selectedMedication: selectedMedicationForViewing ?? medicationManager.selectedMedication!)
                        .padding(.horizontal, -16)
                }

                // Main Education Sections
                EducationSectionsView(selectedMedication: selectedMedicationForViewing ?? medicationManager.selectedMedication)
            }
            .padding()
        }
        .navigationTitle("Learn")
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // Initialize with user's current medication
            selectedMedicationForViewing = medicationManager.selectedMedication
        }
    }
}

// Medication Viewing Selector
struct MedicationViewingSelector: View {
    @Binding var selectedMedication: String?
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Viewing For")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Menu {
                // Show user's medication first
                if let userMedication = medicationManager.selectedMedication {
                    Button(action: {
                        selectedMedication = userMedication
                    }) {
                        Label(userMedication, systemImage: selectedMedication == userMedication ? "checkmark" : "")
                    }
                }

                // Show all available medications
                ForEach(MedicationManager.MedicationType.allCases, id: \.rawValue) { medType in
                    Button(action: {
                        selectedMedication = medType.rawValue
                    }) {
                        Label(medType.rawValue, systemImage: selectedMedication == medType.rawValue ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundColor(.purple)

                    Text(selectedMedication ?? "Select Medication")
                        .font(.headline)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
    }
}

// Education Sections View
struct EducationSectionsView: View {
    let selectedMedication: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Personalized Insights Section
            EducationSectionButton(
                title: "Personalized Insights",
                icon: "lightbulb.fill",
                destination: AnyView(
                    PersonalizedInsightsView(selectedMedication: selectedMedication ?? "Estrogen")
                        .padding()
                )
            )

            // Hormone Therapy Basics Section
            EducationSectionButton(
                title: "Hormone Therapy Basics",
                icon: "pills.fill",
                destination: AnyView(
                    HormoneTherapyBasicsView(medication: selectedMedication ?? "Estrogen")
                        .padding()
                )
            )

            // Timeline & Effects Section
            if selectedMedication == "Estrogen" {
                EducationSectionButton(
                    title: "Feminization Timeline",
                    icon: "calendar",
                    destination: AnyView(
                        EducationFeminizationTimelineView()
                            .padding()
                    )
                )
            } else {
                EducationSectionButton(
                    title: "Masculinization Timeline",
                    icon: "calendar",
                    destination: AnyView(
                        MasculinizationTimelineView()
                            .padding()
                    )
                )
            }

            // Administration & Dosage Section
            EducationSectionButton(
                title: "Administration & Dosage",
                icon: "syringe.fill",
                destination: AnyView(
                    AdministrationDosageView(medication: selectedMedication ?? "Estrogen")
                        .padding()
                )
            )

            // Health Monitoring Section
            EducationSectionButton(
                title: "Health Monitoring",
                icon: "stethoscope",
                destination: AnyView(
                    HealthMonitoringView(medication: selectedMedication ?? "Estrogen")
                        .padding()
                )
            )

            // Resources & Support Section
            EducationSectionButton(
                title: "Resources & Support",
                icon: "book.fill",
                destination: AnyView(
                    ResourcesSupportView(medication: selectedMedication ?? "Estrogen")
                        .padding()
                )
            )
        }
    }
}

// Education Section Button (Large, thumb-sized)
struct EducationSectionButton<Destination: View>: View {
    let title: String
    let icon: String
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(16)
            .frame(minHeight: 70) // Thumb-sized vertical height
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// Personalized Insights View (updated)
struct PersonalizedInsightsView: View {
    @Environment(\.medicationManager) private var medicationManager
    let selectedMedication: String

    private var insights: [String] {
        var result: [String] = []

        guard let method = medicationManager.selectedAdministrationMethod else {
            return ["Select your administration method to see personalized insights."]
        }

        // Get current level if available
        let currentLevel = medicationManager.estimatedRecentLevels(days: 1).last?.value

        if selectedMedication == "Estrogen" {
            result.append("Your estrogen therapy is helping to promote feminization effects. The parabolic pattern you see in your levels is normal for injectable estrogen.")

            if let level = currentLevel {
                if level < 100 {
                    result.append("Your current estrogen level (\(Int(level)) pg/mL) is in the suboptimal range. You may experience more stable mood and better feminization progress as your levels increase.")
                } else if level >= 100 && level < 200 {
                    result.append("Your estrogen level (\(Int(level)) pg/mL) is in the optimal range for feminization. This is where most individuals experience good progress with minimal side effects.")
                } else if level >= 200 && level < 500 {
                    result.append("Your estrogen level (\(Int(level)) pg/mL) is in the high range, which may provide enhanced feminization effects but requires monitoring for potential health risks.")
                } else {
                    result.append("Your estrogen level (\(Int(level)) pg/mL) is quite high. While this may maximize feminization, it's important to monitor for potential health risks like blood clots.")
                }
            }

            // Method-specific insights
            if method == "Injectable" {
                result.append("Injectable estrogen typically provides more stable levels and better feminization results compared to other methods.")
            } else if method == "Cream" {
                result.append("Transdermal estrogen (cream) provides steady absorption and lower risk of blood clots compared to oral or injectable methods.")
            }
        } else {
            result.append("Your testosterone therapy is helping to promote masculinization effects. Consistent levels are important for optimal results.")

            if let level = currentLevel {
                if level < 50 {
                    result.append("Your testosterone level (\(Int(level)) ng/dL) is well suppressed, which is optimal for feminization if that's your goal.")
                } else if level >= 50 && level < 200 {
                    result.append("Your testosterone level (\(Int(level)) ng/dL) shows partial suppression. You may need to adjust your regimen or add an antiandrogen.")
                } else {
                    result.append("Your testosterone level (\(Int(level)) ng/dL) remains in the male range, which may limit feminization progress.")
                }
            }
        }

        // Add some general educational insights
        result.append("Remember that hormone therapy effects take time. Most physical changes develop gradually over months and years.")

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalized Insights")
                .font(.title2)
                .bold()

            Text("Based on your current medication regimen and levels:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .frame(width: 20)

                        Text(insights[index])
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
        )
    }
}

// Hormone Therapy Basics View
struct HormoneTherapyBasicsView: View {
    let medication: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hormone Therapy Basics")
                .font(.title2)
                .bold()

            if medication == "Estrogen" {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Estrogen therapy works by:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            Text("Promoting breast development and fat redistribution")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            Text("Softening skin and reducing body hair growth")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            Text("Suppressing testosterone production")
                        }
                    }
                    .font(.body)
                }

                Text("Typical estrogen forms include injections, patches, gels, and pills. Injectable estrogen is often preferred for its stability and effectiveness.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Testosterone therapy works by:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            Text("Promoting facial and body hair growth")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            Text("Increasing muscle mass and strength")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            Text("Deepening voice over time")
                        }
                    }
                    .font(.body)
                }

                Text("Testosterone can be administered through injections, gels, patches, or pellets. Injections are commonly used for their effectiveness and predictable dosing.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// Feminization Timeline View
struct EducationFeminizationTimelineView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feminization Timeline")
                .font(.title2)
                .bold()

            Text("Typical progression of feminization effects over time:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                EducationTimelineItem(effect: "Breast development", onset: "2-6 months", completion: "2-3 years")
                EducationTimelineItem(effect: "Skin softening", onset: "3-6 months", completion: "Unknown")
                EducationTimelineItem(effect: "Body fat redistribution", onset: "3-6 months", completion: "2-5 years")
                EducationTimelineItem(effect: "Decreased muscle mass", onset: "3-6 months", completion: "1-2 years")
                EducationTimelineItem(effect: "Emotional changes", onset: "Immediate", completion: "Unknown")
                EducationTimelineItem(effect: "Reduced libido", onset: "1-3 months", completion: "Unknown")
                EducationTimelineItem(effect: "Testicular atrophy", onset: "3-6 months", completion: "2-3 years")
            }
        }
        .padding()
    }
}

// Masculinization Timeline View
struct MasculinizationTimelineView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Masculinization Timeline")
                .font(.title2)
                .bold()

            Text("Typical progression of masculinization effects over time:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                EducationTimelineItem(effect: "Facial hair growth", onset: "3-6 months", completion: "2-5 years")
                EducationTimelineItem(effect: "Voice deepening", onset: "3-6 months", completion: "1-2 years")
                EducationTimelineItem(effect: "Increased muscle mass", onset: "3-6 months", completion: "2-5 years")
                EducationTimelineItem(effect: "Body fat redistribution", onset: "3-6 months", completion: "1-2 years")
                EducationTimelineItem(effect: "Clitoral growth", onset: "3-6 months", completion: "1-2 years")
                EducationTimelineItem(effect: "Increased libido", onset: "1-3 months", completion: "Unknown")
                EducationTimelineItem(effect: "Cessation of menstruation", onset: "1-6 months", completion: "Unknown")
            }
        }
        .padding()
    }
}

// Timeline Item Component
struct EducationTimelineItem: View {
    let effect: String
    let onset: String
    let completion: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("• \(effect):")
                .font(.body)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Onset: \(onset)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Completion: \(completion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// Administration & Dosage View
struct AdministrationDosageView: View {
    let medication: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Administration & Dosage")
                .font(.title2)
                .bold()

            if medication == "Estrogen" {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Common Estrogen Administration Methods:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "syringe.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("Injectable")
                                    .font(.subheadline)
                                    .bold()
                                Text("Typical dosage: 0.5-1.0ml weekly")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bandage.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("Transdermal (Patches/Gels)")
                                    .font(.subheadline)
                                    .bold()
                                Text("Typical dosage: 2.5-5g daily")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "pills.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("Oral")
                                    .font(.subheadline)
                                    .bold()
                                Text("Typical dosage: 2-8mg daily")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Text("Injection Site Rotation:")
                    .font(.headline)
                    .padding(.top, 8)

                Text("Rotate injection sites weekly between thighs, buttocks, and abdomen to prevent tissue damage.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Common Testosterone Administration Methods:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "syringe.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("Injectable")
                                    .font(.subheadline)
                                    .bold()
                                Text("Typical dosage: 0.5-1.0ml weekly")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bandage.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("Transdermal (Gels/Patches)")
                                    .font(.subheadline)
                                    .bold()
                                Text("Typical dosage: 2.5-10g daily")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Text("Injection Site Rotation:")
                    .font(.headline)
                    .padding(.top, 8)

                Text("Rotate injection sites weekly between thighs, buttocks, and deltoids to prevent tissue damage.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// Health Monitoring View
struct HealthMonitoringView: View {
    let medication: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Monitoring")
                .font(.title2)
                .bold()

            if medication == "Estrogen" {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Health Monitoring for Estrogen Therapy:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.red)
                            Text("Hormone levels (Estradiol): Every 3-6 months")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.red)
                            Text("Liver function tests: Every 6-12 months")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.red)
                            Text("Blood cell counts: Every 6-12 months")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.red)
                            Text("Blood pressure and cholesterol: Regularly")
                        }
                    }
                    .font(.body)
                }

                Text("Watch for potential side effects:")
                    .font(.headline)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Blood clots (seek immediate medical attention)")
                    Text("• Mood changes or depression")
                    Text("• Headaches or migraines")
                    Text("• Nausea or digestive issues")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Health Monitoring for Testosterone Therapy:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.red)
                            Text("Hormone levels (Testosterone): Every 3-6 months")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.red)
                            Text("Hematocrit levels: Every 3-6 months")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.red)
                            Text("Liver function tests: Every 6-12 months")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.red)
                            Text("Cholesterol and blood pressure: Regularly")
                        }
                    }
                    .font(.body)
                }

                Text("Watch for potential side effects:")
                    .font(.headline)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Acne or oily skin")
                    Text("• Mood changes or aggression")
                    Text("• Hair loss (if genetically predisposed)")
                    Text("• Sleep apnea")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// Resources & Support View
struct ResourcesSupportView: View {
    let medication: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resources & Support")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 12) {
                ResourceItem(
                    title: "WPATH Standards of Care",
                    description: "World Professional Association for Transgender Health guidelines for gender-affirming care.",
                    icon: "book.fill"
                )

                ResourceItem(
                    title: "Endocrine Society Guidelines",
                    description: "Clinical practice guidelines for endocrine treatment of gender-dysphoric individuals.",
                    icon: "stethoscope"
                )

                if medication == "Estrogen" {
                    ResourceItem(
                        title: "Feminizing Hormone Therapy Guide",
                        description: "Comprehensive guide to estrogen therapy and feminization effects.",
                        icon: "pills.fill"
                    )
                } else {
                    ResourceItem(
                        title: "Masculinizing Hormone Therapy Guide",
                        description: "Comprehensive guide to testosterone therapy and masculinization effects.",
                        icon: "pills.fill"
                    )
                }

                ResourceItem(
                    title: "Trans Health Research",
                    description: "Latest scientific research on transgender health and hormone therapy outcomes.",
                    icon: "microscope.fill"
                )

                ResourceItem(
                    title: "Support Communities",
                    description: "Online communities and support groups for individuals undergoing hormone therapy.",
                    icon: "person.2.fill"
                )
            }
        }
        .padding()
    }
}

// Resource Item Component
struct ResourceItem: View {
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

#Preview {
    NavigationStack {
        EducationHubView()
    }
}