# MoveNow - Active Sitting Tracker App

MoveNow is a production-grade Flutter Android application designed to combat sedentary lifestyles by warning users when they remain seated or inactive for too long. If inactive for a configurable period (default: 60 minutes) without walking 100 meters, the app triggers a loud alarm, persistent vibration, and high-priority notifications.

## Key Features
- **Android Foreground Service**: Continuous background tracking that persists even if the app is killed, the phone locks, or the device is restarted.
- **Intelligent Activity Recognition**: Utilizes Android hardware sensors (Step Counter & Accelerometer) to measure steps and gauge motion status (`STILL`, `WALKING`, `RUNNING`, `STANDING`).
- **Dual Custom App Widgets**: Responsive small and large home screen widgets displaying current steps, distance, active minutes, and a quick "Pause/Resume" toggle.
- **Ringing Alarm Alert**: Triggers a loud alarm on loop with continuous vibration patterns, auto-dismissible when the user walks the required distance.
- **Local Analytics Storage**: Native SQLite database logging daily walks, alarms, inactivity timeline, and hourly steps statistics.
- **Material 3 Design**: Clean dark/light theme, custom accent color palettes, glassmorphism dashboard, and timeline components.

---

## Technical Architecture

The app uses a hybrid architecture to ensure maximum background stability on Android:
- **Native Android Layer (Kotlin)**: Manages permissions, the SQLite Database, Sensor listeners, Media Player alarms, and updating Home Screen widgets.
- **Flutter UI Layer (Dart)**: Features a beautiful dashboard with stats, an activity timeline, and configurations. It communicates via MethodChannels and streams live status over an EventChannel.

---

## Folder Structure

```
lib/
├── core/
│   ├── router.dart             # GoRouter navigation configuration
│   └── theme.dart              # Color system, fonts, and dark mode configuration
├── data/
│   └── native_service.dart     # MethodChannel & EventChannel interfaces
├── domain/
│   ├── activity_state.dart     # Live status data model
│   ├── app_settings.dart       # User configuration settings model
│   └── history_event.dart      # SQLite timeline & hourly steps models
└── presentation/
    ├── providers/
    │   ├── history_provider.dart  # Analytics and timeline state
    │   ├── service_provider.dart  # Foreground service controls state
    │   └── settings_provider.dart # SharedPreferences persistent settings
    ├── screens/
    │   ├── dashboard_screen.dart  # Activity rings and real-time status
    │   ├── history_screen.dart    # Daily timeline list and steps chart
    │   ├── settings_screen.dart   # Perms checklist and customization
    │   └── shell_scaffold.dart    # Floating glassmorphic bottom bar
    └── widgets/
        └── progress_ring.dart     # Custom painter dual rings
```

---

## Setup & Running Instructions

### 1. Prerequisites
- **Flutter SDK**: Ensure you have Flutter version 3.22.x or higher installed.
- **Android Device**: Step detection and background service features require a physical Android device or a compatible emulator with sensor support.

### 2. Run Commands
1. Navigate to the project root directory:
   ```bash
   cd movenow
   ```
2. Fetch package dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application on an Android device:
   ```bash
   flutter run
   ```

### 3. Permissions Checklist
When you launch the app, navigate to **Settings** and grant the required permissions:
1. **Activity Recognition**: Enables hardware step counter and motion checks.
2. **Notifications**: Allows showing persistent progress and high-priority alarms.
3. **Battery Optimization Exemption**: Prevents Android OS from killing the background service.

### 4. Installing Home Screen Widgets
1. Go to your Android Home Screen.
2. Long press on the wallpaper and select **Widgets**.
3. Scroll down and locate **MoveNow**.
4. Drag either the **MoveNow Small Widget** (Steps/Distance/Status) or **MoveNow Large Widget** (Countdown/Pause/Steps) to your home screen.
