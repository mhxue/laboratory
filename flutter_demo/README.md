# Flutter Cupertino Demo

## Overview
This is a simple Flutter demo project showcasing Cupertino widgets running across multiple platforms (Android, iOS, and Web).

## Features
- Demonstrates Cupertino-style counter app
- Cross-platform compatibility
- Uses Flutter Version Management (FVM)

## Getting Started

### Prerequisites
- Flutter SDK (version 3.27.0)
- FVM (Flutter Version Management)

### Installation
1. Install FVM:
   ```
   brew install fvm
   ```

2. Clone the repository:
   ```
   git clone <repository-url>
   ```

3. Install dependencies:
   ```
   fvm flutter pub get
   ```

### Running the App
- For Web: 
  ```
  fvm flutter run -d chrome
  ```
- For Android:
  ```
  fvm flutter run -d android
  ```
- For iOS:
  ```
  fvm flutter run -d ios
  ```

## Project Structure
- `lib/main.dart`: Main application entry point
- Cupertino-style counter app with cross-platform support

## Technologies
- Flutter
- Cupertino Widgets
- FVM
