# ✨ Research Insights Dashboard Specification (Mockup Proposal)

**Target Phase:** Phase 2 - Research Foundation
**Purpose:** To transform raw, anonymized user data into compelling, statistically relevant insights consumable by scientists and grant reviewers.
**Goal:** Prove the research utility of the aggregated dataset before seeking institutional funding.

## 📊 Dashboard Overview
The dashboard must be clean, highly visual, and immediately understandable. It should focus on **correlations** and **longitudinal trends**, rather than just showing raw data dumps.

## 🖼️ Key Components & Views

### 1. **The 'Correlation Engine' (Primary View)**
*   **Purpose:** To test the hypothesis: "Does tracking X correlate with better outcomes in Y?"
*   **Functionality:** Requires a selector to pick **Variable A** (e.g., *Mood Score*) and **Variable B** (e.g., *Skin Progress*).
*   **Visualization:** Scatter Plot or Correlation Heatmap.
    *   *Example:* Plotting (Months on HRT) vs (Skin Progress Percentage). A visible upward trend in the cluster suggests a strong correlation.
*   **Output:** A calculated "Correlation Strength Score" (0.0 to 1.0).

### 2. **Longitudinal Trend View (Timeline Analysis)**
*   **Purpose:** To visualize the *rate of change* over time, which is more powerful than a static snapshot.
*   **Functionality:** Selector for a specific system (e.g., "Body Shape").
*   **Visualization:** Line Graph plotted against time (Months on HRT).
    *   *Annotation:* Key milestones (`Breast growth begins`, etc.) must be automatically marked on the graph when the user crosses the threshold in `DATA_REQUIREMENTS.md`.
    *   *Feature:* Ability to overlay the `MedicationManager.estimatedRecentLevels()` decay curve onto the physical metric curve to see if the drug stabilizes the biological process.

### 3. **Adherence & Safety Audit View**
*   **Purpose:** For researchers to monitor adherence patterns and potential adverse events (SAEs).
*   **Metrics Display:**
    *   **Adherence Rate:** (Percentage) % of scheduled doses taken vs. total scheduled.
    *   **Missed Dose Tracker:** A heatmap showing the frequency of missed doses across different time periods (e.g., "High miss rate observed in Q3").
    *   **Event Flagging:** A system for flagging potential SAEs that require manual review by a clinical team.

## 📝 Technical Implication & Next Steps
1.  **Data Structure Refinement:** The `DATA_REQUIREMENTS.md` must be expanded to include quantifiable scores for subjective metrics (e.g., a 1-10 Likert scale for "Mood").
2.  **Backend Pipeline:** This view implies a robust backend service capable of running statistical models (regression, correlation) on the anonymized data, which moves the focus from an app feature to a **Research Service**.