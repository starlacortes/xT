# 📁 xT Project Directory Map

This file provides a full, hierarchical map of all files and folders found within the `/Users/starlacortes/Documents/xT` workspace. This map is crucial for understanding the architecture of the xT project.

## 📂 Directory Structure Overview

*   **Root:** `/Users/starlacortes/Documents/xT/`
    *   **Metadata/Plans:** `README.md`, `SCOPE.md`, `DATA_REQUIREMENTS.md`
    *   **Version Control:** `.git/` (Contains all Git history and object files)
    *   **Code Source Root:** `xT/` (Contains core app modules)
    *   **Build Artifacts:** `xT.xcodeproj/` (The Xcode project container)
    *   **Testing:** `xTTests/`, `xTUITests/` (Automated testing suites)

### 🌲 Detailed Breakdown:

#### 📂 1. Code Source Root: `/xT/`
This is the main container for the application's code, models, and assets.
*   `xT/Assets.xcassets/`: Contains all image and color assets.
    *   `App Icon.appiconset/`: Icon source files.
    *   `AccentColor.colorset/`: Color palette definitions.
    *   `Contents.json`: General asset index.
*   `xT/HomeView/`: Contains the entire UI layer for the main user experience.
    *   `OnboardingView.swift`: The primary flow control for first-time users.
    *   `MainTabView.swift`, `ProfileView.swift`, etc.: Specific screen implementations.
    *   `Components/`: Reusable, modular UI pieces (e.g., `MissedDosePrompt.swift`).
    *   `Themeing/`: Core styling definitions (`Theme.swift`, etc.).
*   `xT/Managers/`: **(Critical Logic Layer)** Contains the complex business logic responsible for state management.
    *   `MedicationManager.swift`: Handles all drug logic, dosing, and tracking calculations.
    *   `ProfileManager.swift`: Manages user-specific data (name, photo).
    *   `SecurityManager.swift`: Implements encryption/decryption for sensitive data.
    *   `JournalManager.swift`: (Present, but logic not yet inspected) Likely handles journal entries/raw logs.
*   `xT/Models/`: Defines the data structures used across the app (`UserPreferences.swift`, `JournalModels.swift`).

#### 📂 2. Testing Suites
*   `xTTests/` & `xTUITests/`: Contain unit and UI tests to validate the functionality of the core components.

#### 📂 3. Project Configuration
*   `xT.xcodeproj/`: The actual Xcode project settings file.
*   `xT.xcodeproj/project.xcworkspace/`: The workspace definition file.

---

This detailed map confirms the architectural layers: **Assets $\rightarrow$ Models $\rightarrow$ Managers (Business Logic) $\rightarrow$ Views (UI)**. This is a very professional, scalable structure.

This structured understanding of the codebase, combined with the **DATA\_REQUIREMENTS.md** contract, means we are perfectly poised for the next phase.

**I recommend we proceed with designing the "Research Insights Dashboard" mock-up (Phase 2).** This will allow us to stress-test the data points in `DATA_REQUIREMENTS.md` against a visible, actionable output, confirming the value proposition for grants and research. 💡