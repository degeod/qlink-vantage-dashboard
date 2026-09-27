# Vantage Control — bronzip gebruiken in een AI-console

Handleiding voor **Vantage-Control-source.zip**: hoe je de broncode opent in Cursor, ChatGPT Codex, Claude, of een vergelijkbare AI-codingconsole.

## 1. Wat is de zip?

`next ai agent.zip` (of `Vantage-Control-source.zip`) bevat de volledige Flutter-bronmap **`vantage-control-android/`**.

| Bestand | Rol |
|---------|-----|
| `Vantage-Control-source.zip` | Broncode voor AI + Flutter-ontwikkeling |
| `Vantage Control.apk` | Alleen installeren op de telefoon (niet genoeg voor AI-wijzigingen) |

Zonder `lib/` kan de AI de app niet verder programmeren. De APK is geen vervanging voor de zip (alleen gecompileerde code). Een zip zonder `phone_remote_screen.dart` of `dashboard_top_band.dart` is verouderd.

## 2. Uitpakken

1. Kopieer `Vantage-Control-source.zip` naar de PC waar de AI-console draait.
2. Pak uit (rechtermuisklik → Uitpakken, of `Expand-Archive`).
3. Je moet deze map zien:  
   `...\vantage-control-android\`
4. Controleer dat o.a. aanwezig zijn:
   - `AGENTS.md`
   - `START_HERE.md`
   - `pubspec.yaml`
   - `lib/`
   - `android/`
   - `assets/`

## 3. Project openen in de AI-console

### Cursor / VS Code + AI

1. **File → Open Folder** → kies `vantage-control-android`.
2. Start een **nieuwe Agent/Chat** in die workspace.
3. Plak de startprompt hieronder.

### Cloud Agent / Codex / vergelijkbaar

1. Upload of koppel de uitgepakte map `vantage-control-android` als workspace/root.
2. Zorg dat de agent **schrijfrechten** heeft op die map.
3. Plak de startprompt; vraag expliciet om `AGENTS.md` eerst te lezen.

### Belangrijk

- Open de map **`vantage-control-android`**, niet alleen de bovenliggende zip-map zonder die submap.
- Laat de AI niet “vanaf nul” een nieuwe app verzinnen als de bron er al is.

## 4. Startprompt (Nederlands — plak dit)

```
Lees eerst AGENTS.md en START_HERE.md in deze map (vantage-control-android/).
Dit is een Flutter Android-app voor een Vantage IPE via VCommand TCP poort 3041.
Werk ALTIJD in de Dart-bronnen, nooit alleen vanuit de APK.
Remote-tab: lib/src/ui/screens/phone_remote_screen.dart
Dashboard-tab: lib/src/ui/screens/dashboard_screen.dart
Vaste balk weer|kalender|memo: lib/src/ui/widgets/dashboard_top_band.dart
Gedeelde state: lib/src/state/dashboard_config.dart
  (memoNote, dayMemos, tileColors, setMemoForDay;
   AppController.setDashboardDayMemo / setDashboardMemoNote;
   UI: _selectDay, _returnToDefaultMemo).
Remote en Dashboard delen tegelkleur- en apparaatinstellingen.
Neu-cirkel: face #32373E, AAN = zelfde schaduwpaar inset (niet inverteren),
haarlijn 2px naar binnen, tween 100 ms, tegelhoogte 68, status naast de naam.
Geen tabula-rasa redesign. applicationId vantage_remote, label Vantage Remote.
Kalender/memo/weer-logica en VLB-fade niet wijzigen bij een restyle.
Bouw verder of pas aan volgens mijn vraag.
Lever daarna vantage-control.apk op de Desktop.
```

Daarna stel je je concrete vraag, bijvoorbeeld:

- “Maak de Dashboard-tegels kleiner”
- “Pas de vaste weer-balk / kalender / memo aan (dashboard_top_band.dart)”
- “Pas de Remote-tab aan (phone_remote_screen.dart) — zelfde kleuren als Dashboard”
- “Pas muur-tablet standby of camera-gevoeligheid aan”
- “Fix QLK-import voor dit bestand”

## 5. Wat de AI eerst moet lezen

| Bestand | Waarom |
|---------|--------|
| `AGENTS.md` | Protocol, paden, build, valkuilen (3041 vs 3040, één TCP-sessie) |
| `START_HERE.md` | Korte draagbare handoff |
| `README.md` | Gebruikers-/buildinfo |

De gids staat ook in `assets/docs/` (mee in de APK), maar **ontwikkelen** gebeurt altijd vanuit de bronmap.

## 6. Tooling op de PC (voor een echte APK-build)

De AI kan code wijzigen zonder Flutter, maar voor een nieuwe APK heb je nodig:

- Flutter SDK
- Android SDK
- JDK 17

Voorbeeld (Windows):

```bat
set PATH=D:\dev\flutter\bin;%PATH%
set ANDROID_HOME=D:\Android\Sdk
cd vantage-control-android
flutter pub get
flutter build apk --release
```

APK-uitvoer:

- `build\app\outputs\flutter-apk\app-release.apk`
- Kopieer/hernoem naar **`Vantage Control.apk`**

Als Flutter/SDK ontbreekt: vraag de AI om de code-wijzigingen wél te doen en de build-stappen te documenteren.

## 7. Protocol-geheugensteuntjes (kort)

- Bediening: TCP **3041** (VCommand), niet QLink **3040**
- IPE laat vaak **maar één** TCP-client toe → WebPoint/QLink sluiten tijdens app-gebruik
- Loads: `VLB` · Keypad: `VSW# … 6`
- QLK laden in de app = alleen UI-import (programmeert de Master niet)

## 8. Na afloop opnieuw inpakken (optioneel)

Als je de bron opnieuw wilt delen:

1. Zip de map `vantage-control-android/`
2. Laat `build/` en `.dart_tool/` weg (niet nodig voor AI)
3. Vervang `Vantage-Control-source.zip` + eventueel de nieuwe APK

## 9. Checklist

- [ ] Zip uitgepakt
- [ ] Map `vantage-control-android` geopend in de AI-console
- [ ] Startprompt geplakt (AGENTS.md eerst)
- [ ] Concrete taak gesteld
- [ ] Nieuwe APK gevraagd / gebouwd
- [ ] Getest op de telefoon (sideload)
