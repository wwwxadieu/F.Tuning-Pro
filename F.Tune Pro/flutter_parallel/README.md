# F.Tune Pro Flutter Parallel

This folder contains a parallel Flutter desktop prototype for `F.Tune Pro`.
The current Electron app remains untouched and is still the primary app.

## Current status

- Flutter source scaffold only
- Reuses existing local data/assets from the Electron project
- Includes a multi-screen Flutter shell for Dashboard, Create, Garage, and Settings
- Includes a first-pass Dart tuning calculation service ported from `renderer.js`
- Includes a Flutter-side tune results preview dialog with calculated setup cards and gearing estimates
- Flutter SDK is not installed on this machine yet, so this version has not been generated with `flutter create` or run locally

## Planned use

This parallel app is meant for an incremental migration:

1. keep Electron running as-is
2. rebuild the Create screen in Flutter
3. port shared tuning logic into pure modules
4. compare behavior side-by-side before switching over

## When Flutter SDK is installed

From this folder, run:

```powershell
./tool/bootstrap_flutter.ps1
flutter run -d windows
```

If you only want Windows support:

```powershell
./tool/bootstrap_flutter.ps1 -Platforms windows
flutter run -d windows
```

## Notes

- Assets expected by this scaffold live in `assets/data` and `assets/images`
- The first pass focuses on the `Create New Tune` screen only
- Electron files in the project root are intentionally left unchanged
