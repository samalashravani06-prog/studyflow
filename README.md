
# STUDYFLOW

1. Open this folder in VS Code (File > Open Folder).
2. Replace everything in `lib/main.dart` with your StudyFlow code.
3. In the VS Code terminal run:
   flutter create . --project-name studyflow --platforms=android,ios,web,windows
   flutter pub get
4. Pick a device (bottom-right of VS Code, e.g. Chrome / Windows / emulator) and press F5.

# StudyFlow

**Daily Motivation** (for specifically students) built with Flutter and Dart.

StudyFlow brings a student's study tasks, health routines, and daily habits into one simple, responsive app, with a clear view of progress.

Submitted for: UI Design – Flutter (CS506PC) External Laboratory Examination
Student: Samala Shravani | Roll No: 24XV1M6642 | B.Tech CSE (AI-ML), CR Rao AIMSCS

---

## Features

- **Dashboard** – combined overview of study, health, and habits
- **Study Tracker** – add study tasks and goals, mark them complete
- **Health Tracker** – record daily health activities
- **Habit Tracker** – track daily habits and completion
- **Progress Summary** – counters and progress indicators
- **Responsive UI** – works on desktop, tablet, and mobile screens
- **Cross-platform** – Android, iOS, Web, and Windows from one codebase

## Tech Stack

| Technology | Purpose |
|---|---|
| Flutter (Dart SDK >=3.0.0 <4.0.0) | UI framework |
| Dart | Application logic |
| Material Design | Widgets and theming |
| flutter_lints ^3.0.0 | Static analysis |
| Visual Studio Code | Development |

## Project Structure

```
studyflow/
├── lib/
│   └── main.dart            # App entry point and source code
├── .vscode/
│   └── launch.json          # Debug / profile / release configurations
├── analysis_options.yaml    # Lint rules
├── pubspec.yaml             # Project metadata and dependencies
├── README.md
└── .gitignore
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
- Visual Studio Code with the Flutter and Dart extensions
- Chrome, an Android emulator, or Windows desktop support enabled

Check your setup with:

```bash
flutter doctor
```

## Getting Started

1. Clone the repository:
   ```bash
   git clone <YOUR-REPOSITORY-URL>
   cd studyflow
   ```
2. Generate the platform folders (first time only):
   ```bash
   flutter create . --project-name studyflow --platforms=android,ios,web,windows
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   - In VS Code, choose a device (Chrome / Windows / emulator) at the bottom-right and press **F5**, or
   - From the terminal:
     ```bash
     flutter run -d chrome
     ```

## Build

```bash
flutter build web --release      # output in build/web
flutter build windows --release
flutter build apk --release
```

'

## Author

**Samala Shravani** – 24XV1M6642 – B.Tech CSE (AI-ML), CR Rao AIMSCS

## License

This project was created for educational purposes.
