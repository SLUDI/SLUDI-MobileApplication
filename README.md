# SLUDI Mobile Application

SLUDI-MobileApplication is a cross-platform mobile app project primarily using HTML, Dart (Flutter), and native code (C++, Swift, C). This app serves as the mobile companion for the SLUDI platform.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technologies Used](#technologies-used)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Overview

This repository contains the source code for the SLUDI Mobile Application, designed to run on both Android and iOS devices. The project leverages Flutter for UI and cross-platform logic, with integrations to native modules for advanced features.

## Features

- Cross-platform support (Android and iOS)
- Modern UI with Flutter
- Native integrations for performance-critical tasks
- Modular codebase for scalability

## Technologies Used

- **HTML** – UI and content rendering
- **Dart (Flutter)** – Main application framework
- **C++** – Native modules and performance
- **CMake** – Build system for native code
- **Swift** – iOS-specific code
- **C** – Low-level operations

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Dart](https://dart.dev/get-dart)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) for platform-specific builds
- CMake, Git, and platform-specific SDKs

### Installation

1. **Clone the repository**
    ```sh
    git clone https://github.com/SLUDI/SLUDI-MobileApplication.git
    cd SLUDI-MobileApplication
    ```

2. **Install dependencies**
    ```sh
    flutter pub get
    ```

3. **Run the app**
    - For Android:
      ```sh
      flutter run
      ```
    - For iOS:
      ```sh
      flutter run
      ```

> **Note:** For native module development, ensure you have CMake and platform toolchains installed.

## Project Structure

```
SLUDI-MobileApplication/
├── lib/            # Dart and Flutter source code
├── android/        # Android platform native code
├── ios/            # iOS platform native code (Swift, Obj-C)
├── cpp/ or native/ # C++ and C source files (if present)
├── assets/         # Static assets (images, fonts, etc.)
├── pubspec.yaml    # Flutter/Dart dependencies
└── README.md
```

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request. For major changes, open an issue first to discuss your ideas.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a pull request

## Contact

For questions or support, please create an issue or contact the maintainers.

---
