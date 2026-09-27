# Vantage Control — using the source zip in an AI console

Guide for **Vantage-Control-source.zip**: how to open the source in Cursor, ChatGPT Codex, Claude, or a similar AI coding console.

## 1. What is the zip?

`next ai agent.zip` (or `Vantage-Control-source.zip`) contains the full Flutter source folder **`vantage-control-android/`**.

| File | Role |
|------|------|
| `Vantage-Control-source.zip` | Source for AI + Flutter development |
| `Vantage Control.apk` | Phone install only (not enough for AI code changes) |

Without `lib/`, the AI cannot continue developing the app. The APK does not replace the zip (compiled code only). A zip missing `phone_remote_screen.dart` or `dashboard_top_band.dart` is obsolete.

## 2. Unpack

1. Copy `Vantage-Control-source.zip` to the PC that runs the AI console.
2. Extract it (right-click → Extract, or `Expand-Archive`).
3. You should see:  
   `...\vantage-control-android\`
4. Confirm these exist:
   - `AGENTS.md`
   - `START_HERE.md`
   - `pubspec.yaml`
   - `lib/`
   - `android/`
   - `assets/`

## 3. Open the project in the AI console

### Cursor / VS Code + AI

1. **File → Open Folder** → select `vantage-control-android`.
2. Start a **new Agent/Chat** in that workspace.
3. Paste the starter prompt below.

### Cloud Agent / Codex / similar

1. Upload or attach the extracted `vantage-control-android` folder as the workspace/root.
2. Give the agent **write access** to that folder.
3. Paste the starter prompt; explicitly ask it to read `AGENTS.md` first.

### Important

- Open the **`vantage-control-android`** folder, not only a parent folder that happens to contain the zip.
- Do not let the AI invent a new app from scratch when the source is already present.

## 4. Starter prompt (English — paste this)

```
Read AGENTS.md and START_HERE.md in this folder (vantage-control-android/) first.
This is a Flutter Android app for a Vantage IPE over VCommand TCP port 3041.
Always edit the Dart sources, never the APK alone.
Remote tab: lib/src/ui/screens/phone_remote_screen.dart
Dashboard tab: lib/src/ui/screens/dashboard_screen.dart
Fixed weather|calendar|memo band: lib/src/ui/widgets/dashboard_top_band.dart
Shared state: lib/src/state/dashboard_config.dart
  (memoNote, dayMemos, tileColors, setMemoForDay;
   AppController.setDashboardDayMemo / setDashboardMemoNote;
   UI: _selectDay, _returnToDefaultMemo).
Remote and Dashboard share tile colors and device settings.
Neu circle: face #32373E, ON = same shadow pair inset (do not invert),
2px inward hairline, 100 ms tween, tile height 68, status beside the name.
No tabula-rasa redesign. applicationId vantage_remote, label Vantage Remote.
Do not change calendar/memo/weather logic or VLB fade on a restyle.
Continue or change the app according to my request.
Then put vantage-control.apk on the Desktop.
```

Then add your concrete task, for example:

- “Make the Dashboard tiles smaller”
- “Adjust the fixed weather / calendar / memo band (dashboard_top_band.dart)”
- “Adjust the Remote tab (phone_remote_screen.dart) — same colors as Dashboard”
- “Tune wall-tablet standby or motion sensitivity”
- “Fix QLK import for this file”

## 5. What the AI should read first

| File | Why |
|------|-----|
| `AGENTS.md` | Protocol, paths, build, pitfalls (3041 vs 3040, single TCP session) |
| `START_HERE.md` | Short portable handoff |
| `README.md` | User/build info |

The guide is also in `assets/docs/` (shipped inside the APK), but **development** always happens from the source folder.

## 6. Tooling on the PC (for a real APK build)

The AI can edit code without Flutter, but a new APK needs:

- Flutter SDK
- Android SDK
- JDK 17

Example (Windows):

```bat
set PATH=D:\dev\flutter\bin;%PATH%
set ANDROID_HOME=D:\Android\Sdk
cd vantage-control-android
flutter pub get
flutter build apk --release
```

APK output:

- `build\app\outputs\flutter-apk\app-release.apk`
- Copy/rename to **`Vantage Control.apk`**

If Flutter/SDK is missing: ask the AI to still make the code changes and document the build steps.

## 7. Protocol reminders (short)

- Control traffic: TCP **3041** (VCommand), not QLink **3040**
- The IPE often allows **only one** TCP client → close WebPoint/QLink while using the app
- Loads: `VLB` · Keypad: `VSW# … 6`
- Loading a QLK in the app is UI-import only (does not reprogram the Master)

## 8. Re-pack after changes (optional)

To share the source again:

1. Zip the `vantage-control-android/` folder
2. Omit `build/` and `.dart_tool/` (not needed for AI)
3. Replace `Vantage-Control-source.zip` and optionally the new APK

## 9. Checklist

- [ ] Zip extracted
- [ ] Folder `vantage-control-android` opened in the AI console
- [ ] Starter prompt pasted (AGENTS.md first)
- [ ] Concrete task given
- [ ] New APK requested / built
- [ ] Tested on the phone (sideload)
