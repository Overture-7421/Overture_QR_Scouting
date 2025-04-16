# Overture Reefscape QR Scouting App

## Overview

This is a Flutter-based scouting application designed for the FIRST Robotics Competition (FRC) game "Reefscape". The app provides a user-friendly interface for collecting match data during competitions and generates a QR code containing all the gathered information for easy transfer and analysis.

The primary goal is to streamline the scouting process by allowing scouters to quickly input data on a mobile device or desktop and then generate a scannable QR code or copy the data directly.

## Features

*   **Cross-Platform:** Built with Flutter, enabling compilation for Android, iOS, Windows, macOS, Linux and Web.
*   **Structured Data Entry:** Divides scouting data into logical sections:
    *   **Prematch:** Scouter Initials, Match Number, Robot Selection, Alliance Info, Team Number, Starting Position, No Show status.
    *   **Autonomous:** Moved status, Coral Scoring (Levels 1-4), Algae Scoring (Barge/Processor), Dislodged Algae, Auto Fouls.
    *   **Teleop:** Dislodged Algae, Pickup Location, Coral Scoring (Levels 1-4), Algae Scoring (Barge/Processor), Defense/Crossing Field, Tipped/Fell, Touched Opposing Cage, Died status.
    *   **Endgame:** End Position (Parked, Climb Levels), Broke status, Defended status, Coral HP Mistake, Yellow/Red Card status.
*   **Intuitive UI:** Uses standard Flutter widgets like TextFields, Dropdowns, Switches, and custom Counter fields for efficient data input.
*   **QR Code Generation:** Generates a QR code containing all collected data, separated by tabs (`\t`), upon clicking the "Commit" button.
*   **Data Copying:**
    *   Option to copy the raw tab-separated data string directly to the clipboard.
    *   Option to copy a comma-separated list of the data column headers (useful for setting up spreadsheets).
*   **Form Reset:** Quickly clears most fields and increments the match number for the next match, keeping scouter initials and robot selection.
*   **Dark Theme:** Features a visually appealing dark theme suitable for event environments.

## How to Use

1.  **Fill the Form:** Enter all relevant data for the match in the corresponding fields across the Prematch, Autonomous, Teleop, and Endgame sections.
2.  **Commit Data:** Once the match is complete and data is entered, click the "Commit" button.
3.  **Scan or Copy:**
    *   A dialog box will appear displaying a QR code. Scan this code using a compatible QR scanning application or device.
    *   Alternatively, use the "Copy Info" button to copy the tab-separated data string or the "Copy Columns" button to copy the CSV header row.
4.  **Reset for Next Match:** Click the "Reset Form" button. This will clear the form data (while incrementing the match number and keeping scouter/robot info) ready for the next match scouting.

## Building the App

You need to have the [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.

1.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd overture_qr_scouting
    ```
2.  **Get dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Build for your target platform:**
    *   **Android:** `flutter build apk` or `flutter build appbundle`
    *   **iOS:** `flutter build ios` (Requires macOS and Xcode setup)
    *   **Windows:** `flutter build windows` (Requires Windows setup enabled via `flutter config --enable-windows-desktop`)
    *   **macOS:** `flutter build macos` (Requires macOS and Xcode setup)
    *   **Linux:** `flutter build linux` (Requires Linux setup enabled via `flutter config --enable-linux-desktop`)

    The output files will be located in the `build` directory within your project folder.

## Screenshots
![Screenshot 2025-04-13 143318](https://github.com/user-attachments/assets/5c409612-1a39-4e35-b55c-bf32726c68dd)
![Screenshot 2025-04-13 143308](https://github.com/user-attachments/assets/c017fdba-d3de-4d28-a080-4c57b6df0f5b)
