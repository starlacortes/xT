# ⚙️ DATA REQUIREMENTS CHECKLIST for xT MVP

**Date Last Updated:** [Current Date]
**Dependencies:** MedicationManager.swift, ProfileManager.swift (Assumed)

## 📝 Purpose
This document serves as the **Contract of Record** for the Minimum Viable Product (MVP). Every data point listed here is a required input, output, or state that the tracking system must manage. Any feature added without validating against this checklist increases scope risk.

## 🧬 Core Data Modules

### 1. Medication Data (Driven by MedicationManager)
*   **Medication Name:** (String) Must be standardized (e.g., "Estrogen", "Testosterone").
*   **Type:** (Enum) Must map to predefined `MedicationType` cases.
*   **Administration Method:** (Enum) Must map to predefined `AdministrationMethod` cases.
*   **Dosage Info:** (String/Structured Data) Must dynamically change based on (Type + Method).
*   **Frequency:** (Int/Days) The interval (e.g., 7 days, 1 day) dictates scheduling.

### 👤 User Profile Data (Driven by ProfileManager)
*   **User Name:** (String)
*   **Date of Birth (DOB):** (Date) Essential for medical context and age-related insights.
*   **Profile Image/Avatar:** (Asset/URL)
*   **Personal Notes:** (String) For user context.

### 🗓️ Tracking Data (The Core Log)
*   **Injection Record:** (Object)
    *   `DateTaken`: (Date) **Mandatory**.
    *   `Medication`: (Reference to Medication Data).
    *   `DosageGiven`: (Double/String) The actual amount logged for this specific event.
*   **State Tracking:**
    *   `LastDoseDate`: (Date) Used to calculate subsequent doses.
    *   `NextDoseDate`: (Date) The system's primary reminder trigger.
    *   `StreakDays`: (Int) Current consecutive adherence count.
    *   `MonthsOnHRT`: (Int) Calculated from the first dose date.

### 🔬 Research Data (Future Proofing)
*   **Biomarker Tracking:** (Object/Chart Data)
    *   `HormoneLevelEstimate`: (Double) The predicted value at a given time.
    *   `ReportedRange`: (String) The calculated status (e.g., "Low", "Optimal").
    *   `SystemProgress`: (Map<SystemName, {Progress: Double, Status: String}>) To track body changes over time.

## 🔗 Data Relationships Summary
*   A **Tracking Record** links back to a **Medication Type** and an **Admin Method**.
*   **Profile Data** contextualizes all tracking data.
*   **Research Data** is derived by analyzing patterns across **Tracking Records** over time.

---
**NEXT:** With the data contract locked down, I believe the next *logical* step is to tackle **Phase 2: Research Foundation**. We can start designing the **Data Schema** that will allow us to take the logged data and transform it into "insights" for scientists.