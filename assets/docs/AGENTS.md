# QLink Vantage dashboard — AI / onderhoudsgids

Lees dit bestand **eerst**. Dit is een **QLink / Vantage Q dashboard** (tablet + remote) op IPE VCommand, geen vervanger van QLink.

**Kern:** Dashboard-tab + Remote-tab, QLK-import, lights/macros, kalender/weer/memo. Dat moet in de publieke repo blijven staan — mensen zoeken op “QLink Vantage”.

**Twee APK’s, dezelfde dashboard-UI:**

| | Hoofd-app | Deze map |
|--|-----------|----------|
| Map | `vantage-control-android/` | `vantage-nvr-android/` |
| Label | Vantage Remote | Vantage NVR |
| `applicationId` | `com.vantage.control.vantage_remote` | `com.vantage.control.vantage_nvr` |
| Foscam/IvyIo | **niet** | FN8108W live via IvyIo |

**Draagbaar:** zip `vantage-nvr-android/` (bron). Gids ook in `assets/docs/`. NVR-build heeft lokaal de IvyIo-AAR nodig.

**SIZE LOCK (cirkel AAN/UIT, 2026-09-06):** `neo_icon_well.dart` — `size` 40, `_aanGrow = 21.5/18.5`, `OverflowBox` verplicht. Schaduw `2.8k/1.0k` + `3.4k/6.0k`. **Nooit** herschalen. Zie blok *Knop = cirkel*.

## Wat is dit project?

**QLink Vantage dashboard:** Flutter Android-app voor een Vantage Q-systeem dat je in **QLink** programmeert (`.qlk`) en via **IPE1000-P / VCommand TCP 3041** bedient. Dashboard = lights/macros-raster + vaste weer/kalender/memo. Daarnaast (deze APK) Foscam NVR-live via IvyIo.

- Launcher-label: **Vantage NVR**
- `applicationId`: `com.vantage.control.vantage_nvr`
- Kotlin namespace: `com.vantage.control.vantage_control` (niet wijzigen)
- Projectmap: `vantage-nvr-android/`
- Geen Play Store; release via `flutter build apk --release`
- Desktop-APK: **`vantage-nvr.apk`** / `Vantage-NVR.apk`

Vantage-deel is **geen** poort van de Windows WebPoint-DLL’s. NVR-deel is **geen** RTSP/ONVIF/CGI-gok: FN8108W-B4 heeft die paden niet voor third-party Flutter.

## Foscam FN8108W + IvyIo (2026-09-27)

Kit: **FN8108W-B4** + mesh-camera’s **FI9911W** (alleen bij de kit-NVR; geen standalone IPC). NVR LAN vaak via Cisco uWGB naar huis-wifi. Historisch NVR-IP `192.168.0.6`. Poort 80 HTTP; 88/554/443 dicht; CGIProxy 404. **Geen RTSP/ONVIF-live** op dit model. Kit-IPC “can only be used for NVR in kit.”

**Enige gedocumenteerde Android-live:** IvyIo SDK (`SDKManager` + `IvyNVR.loginDevice` + `VideoSurfaceViewNVR.openNVRVideo`). Demo: [IVYIoT/android-app-sdk-demo](https://github.com/IVYIoT/android-app-sdk-demo). AAR: `ipclibrary_*.aar` in `android/app/libs/` — **niet in git** (vendor-binary). Lokaal leggen vanuit de officiële demo `app/libs`.

### Login (officieel)

- `IvyNVR`: alleen `uid` + `usrName` + `password` (geen IP-veld). User default `admin`.
- `com.ivyio.sdk.Result`: `0` OK, **`3` USR_OR_PWD_ERR**, `11` TIMEOUT, `14` OFFLINE, `15` OK_ON_RESET_STATE (wachtwoord zetten in Foscam-app).
- Leeg wachtwoord: `SDKManager.getFactoryPassword(uid)` als UID-char 22 in `89ABCDEF…` (IvyCryptoJni). Anders `""`. **Geen** hardcoded NVR-wachtwoord, geen Orange PSK, geen 6001-packets verzinnen.
- Na login: `getIPCListInfo` → kanaallijst.

### Live + kanalen

- PlatformView `vantage_nvr/surface` → `VideoSurfaceViewNVR.openNVRVideo(nvr, channel, STREAM_MAIN|STREAM_SUB, listener)`.
- MethodChannel `vantage/nvr`: `discover`, `login`, `channels`, `logout`.
- Dashboard: 2×5 gat in 6 kolommen. Beeld **16:9 cover** (geen hoogte-stretch, geen letterbox). Overlay-balk **CAM 1 2 3 4 alle**.
- Multi: 2–4 kanalen = 2×2 + `STREAM_SUB`. Persist: `nvrSelectedChannels`.
- Lights-tab: tik naam → IPE load (enc/mod/load). 16 placeholder-loads = 2×MDS8 (`Load <master> 1 1 1` … `1 2 8`), schakelen via `VLB` (niet lokaal faken).

### Verboden

- Geen RTSP/VLC/ONVIF/CGI-probe in deze of de hoofd-app.
- Geen reverse-engineering poort 6001.
- Geen gissen van ongepubliceerd protocol.
- Credentials niet hardcoden, niet in git.

## Belangrijke paden

| Pad | Inhoud |
|-----|--------|
| `lib/main.dart` | App start, Provider |
| `lib/src/protocol/vcommand_client.dart` | TCP VCommand-client |
| `lib/src/state/app_controller.dart` | State, connect, rename, macros, QLK-import |
| `lib/src/models/devices.dart` | Light / Keypad / Macro / … |
| `lib/src/data/project_importer.dart` | WebPoint CONFIG/master XML → project |
| `lib/src/data/qlk_importer.dart` | `.qlk` tekstparse → project |
| `lib/src/ui/screens/` | Home, **Remote**, **Dashboard**, Lights, Keypads, Macros, Schedules, Temp, Time, Settings |
| `lib/src/ui/screens/phone_remote_screen.dart` | **Remote-tab** (telefoon-afstandsbediening). Deelt tegelkleur + apparaatinstellingen met Dashboard |
| `lib/src/ui/screens/dashboard_screen.dart` | **Dashboard-tab**: topbalk + tile-raster + muur-tablet |
| `lib/src/state/dashboard_config.dart` | Gedeelde persistente state: pins, raster, `memoNote`, `dayMemos`, `tileColors`, `remoteOrder`, wall-tablet |
| `lib/src/ui/widgets/dashboard_top_band.dart` | Vaste balk: weer (eigen kader) \| kalender + memo samen (kalender/afspraak-logica) |
| `lib/src/ui/widgets/glass_panel.dart` | `GlassPanel` (weer/kalender/memo glas) + `GlassBackdrop` (RAL 9011) |
| `lib/src/ui/widgets/neo_icon_well.dart` | **Knop = cirkel** (neumorphic uit/in, geen verspringing) |
| `lib/src/ui/widgets/neo_device_tile.dart` | Load/macro-tegel: cirkel + naam + dim-slider of toggle-LED |
| `lib/src/ui/widgets/wall_tablet_presence.dart` | Muur-tablet: 3 min standby + analoge klok + camera-beweging → wekken + IPE |
| `lib/src/ui/widgets/standby_analog_clock.dart` | Standby-klok (CustomPainter, midden, ~40% korte zijde) |
| `assets/branding/vantage_app_icon.png` | Bron launcher-icoon (glanzende V); regenereer via `tools/gen_launcher_icons.py` |
| `assets/project/config.xml` | Bundled WebPoint export (loads/keypads) |
| `assets/project/master.xml` | Master TCP-instellingen (host/poort) |
| `lib/src/data/ivy_nvr_client.dart` | Flutter → MethodChannel `vantage/nvr` |
| `lib/src/ui/widgets/nvr_live_panel.dart` | Live-vak + CAM-balk + 16:9 cover |
| `android/app/src/main/kotlin/.../NvrPlugin.kt` | IvyIo discover/login + `Result`-teksten |
| `android/app/src/main/kotlin/.../NvrSurfaceFactory.kt` | `VideoSurfaceViewNVR` per kanaal |
| `android/app/src/main/kotlin/.../NvrSession.kt` | Gedeelde `IvyNVR`-handle |
| `android/app/src/main/AndroidManifest.xml` | Label **Vantage NVR**, INTERNET, CAMERA, WIFI |
| `android/app/src/main/kotlin/.../MainActivity.kt` | `vantage/display` + `vantage/nvr` + factory `vantage_nvr/surface` |
| `android/app/build.gradle.kts` | `applicationId` `vantage_nvr`, `archivesName` `vantage-nvr`, AAR, minSdk 21 |
| `README.md` | Gebruikersbuild + router-uitleg |
| `AGENTS.md` | Dit bestand |

### Externe bronnen (buiten de app)

| Bron | Waar | Waarom |
|------|------|--------|
| Werkende WebPoint-installatie | `C:\Program Files (x86)\Vantage\WebPoint\` | Logs, CONFIG, Upload-*.qlk, HTML-templates |
| Master/config DB | `...\WebPoint\DB\CAppList~6~Dir\CVantageQService~1026~Dir\...` | Actuele objecten na QLK-upload in WebPoint |
| WebPoint logs | `...\WebPoint\Logs\VantageQ-thuis\` | Bewijs van `VLB`, `VSW#`, `RGB#`, `ROS` |
| QLink Explorer protocol | `Documents\Codex\2026-07-15\...\QLinkExplorer-work\qlink_explorer\protocol\client.py` | `VLB`, `VSW` press/release, framing |
| QLK-parser referentie | `...\qlink_explorer\project\qlk_parser.py` | Tekstueel `.qlk` formaat |
| Codex-diagnose (WebPoint TCP 3041) | eerdere chat “WebPoint TCP 3041 fix” | Poort 3041 vs 3040, dubbele Home.exe |
| IvyIo Android SDK demo | https://github.com/IVYIoT/android-app-sdk-demo | Officiële NVR-login + `VideoSurfaceViewNVR` |
| IvyIo Result-codes | `com.ivyio.sdk.Result` in IvyIoSdkJni.jar | `USR_OR_PWD_ERR = 3` |

## Protocol (kritisch)

- **Bediening (deze app):** TCP **`192.168.1.33:3041`** (VCommand / HostPort)
- **QLink programmeren:** poort **`3040`** — **niet** gebruiken voor deze app
- Framing: regels eindigen op CR (`\r`); keepalive periodiek `\r`
- IPE staat vaak **maar één TCP-client** toe → WebPoint (`Home.exe`) en QLink **dicht** tijdens app-gebruik

### Commando’s die we gebruiken

| Actie | Commando | Opmerking |
|-------|----------|-----------|
| Load zetten | `VLB master enc mod load level [fade]` | Bewezen via WebPoint + Explorer |
| Load status | `VGB# master enc mod load` | Antwoord o.a. `RGB# … level` |
| Station list | `VLS# master station` | |
| Keypad knop | Bij voorkeur WebPoint-stijl `VSW# master station switch 6` | Logs toonden state **6**, niet 1/8 |
| Alternatief keypad | `VSW master station switch 1` dan `0` | Explorer press/release; Dim-knoppen zijn gevoelig voor timing |
| Sessie | `VOS 0 1` | Bij connect |
| Macro op controller | `VMA …` | Vaak **niet** betrouwbaar op dit Q-systeem |

Dim-knoppen in QLK (bv. `Event: … DIM …` + `LdA:`) togglen tussen uit en preset. Te snelle press/release kan “alleen uit” lijken — gebruik WebPoint-pulse of langere delay.

## Verbinding: LAN vs router

State: `NetworkProfile.local` / `.remote` in `app_controller.dart`.

- **Local LAN:** IPE IP + 3041 (default `192.168.1.33`)
- **Via router:** WAN/DynDNS + externe TCP-poort → router forward naar `192.168.1.33:3041`
- UI-uitleg: `connection_help_screen.dart` + Settings-knop

## Projectdata / QLK

1. **Bundled:** `assets/project/*.xml` (huidige testproject: 1 load, 2 keypads — **geen echte Macro:-records**)
2. **QLK laden:** Settings (bovenaan) → “QLK-bestand selecteren & laden” (`FileType.any` + `QlkImporter`)
3. Persistent: `documents/imported_project.qlk` + `qlkSourceName` — blijft na herstart
4. QLK is **UI-import only** — programmeert de Master niet opnieuw (dat blijft QLink/WebPoint)
5. Nieuwe loads/knoppen uit QLK schakelen via `VLB` / `VSW#` als ze op de Master bestaan

### Macro’s (belangrijk verschil met WebPoint)

In **WebPoint** zijn macro’s **niet** automatisch alle keuzes uit de QLK. Ze worden **in WebPoint aangemaakt**:

- Naam, room, assigned button (`CreateMacro.html`)
- Macro-regels: delay + acties op loads/devices (`MacroDetail.html`)
- Gebaseerd op objecten die na “Upload QLK” in WebPoint staan

Het bundled test-QLK bevat **geen** `Macro:`-regels; wel knop-events (`DIM` + `LdA`). Daarom toonde de app eerst demo “All Off” / “Evening” die niets deden via `VMA`.

**App-gedrag (phone-side scenes) — geïmplementeerd:**

- UI: `macros_screen.dart` — lijst + `MacroEditorScreen` (loads aanvinken + %)
- Snelkeuze: All Off 0% / Evening 35% / All On 100%
- Uitvoeren: opeenvolgende `VLB` (`runMacro` in `app_controller.dart`)
- Persistent: `SharedPreferences` key `macroConfigsJson` (ook lokale scenes na herstart)
- Demo “All Off” / “Evening” starten leeg tot je ze bewerkt

Mogelijke latere uitbreiding (WebPoint-pariteit): room, assigned keypad-button, delay per regel.

## Custom namen

- Loads / keypads / knoppen hernoemen → `customNamesJson` in SharedPreferences
- Keys: `light:<key>`, `keypad:<key>`, `button:<keypadKey>:<switch>`
- UI: potlood / long-press; knoptekst met `FittedBox` in `keypads_screen.dart`

## Bron vs APK (verplicht voor AI-agents)

- **`Vantage-Control-source.zip` / map `vantage-control-android/`** = enige betrouwbare bron om te wijzigen.
- **APK** bevat alleen **gecompileerde** Flutter-code. Je kunt structuur vermoeden, maar **niet** betrouwbaar alleen styling of kalender/memo-gedrag wijzigen vanuit de APK.
- Een oudere zip **zonder** `phone_remote_screen.dart`, `dashboard_top_band.dart`, `neo_icon_well.dart` of `neo_device_tile.dart` is **achterhaald**. Gebruik altijd deze bestanden:

| Bestand | Rol |
|---------|-----|
| `lib/src/ui/screens/phone_remote_screen.dart` | Remote-tab |
| `lib/src/ui/screens/dashboard_screen.dart` | Dashboard-tab (raster + wrap van de topbalk) |
| `lib/src/ui/widgets/dashboard_top_band.dart` | Vaste balk weer \| kalender \| memo |
| `lib/src/state/dashboard_config.dart` | Gedeelde persistente config (Remote + Dashboard) |
| `lib/src/ui/widgets/neo_icon_well.dart` | Cirkelknop (Soft UI) |
| `lib/src/ui/widgets/neo_device_tile.dart` | Tegel layout: knop, naam, slider, LED |
| `lib/src/ui/widgets/glass_panel.dart` | Achtergrond RAL 9011 + glas voor weer/kalender/memo |

Kalender/memo-state (niet opnieuw verzinnen):

- Persist: `memoNote` (boodschappenlijst), `dayMemos` (afspraken per `YYYY-MM-DD`)
- Schrijven: `AppController.setDashboardMemoNote` / `setDashboardDayMemo` → `DashboardConfig.setMemoForDay`
- UI: `_selectDay`, `_returnToDefaultMemo`, `_returnToGeneralMemo`, `_confirmDay`, `_clearMark` in `dashboard_top_band.dart`
- Op de **dag van een afspraak** toont memo die afspraak; **C** wist → boodschappenlijst terug

Remote en Dashboard **delen** `tileColors`, namen/iconen, `lightControlModes`, pins/macros via dezelfde `AppController.dashboard`. Wijzig die state op één plek.

**Styling vs logica:** kalender/memo/weer-gedrag, VLB-fade en protocol **niet** wijzigen bij een UI-restyle. Alleen `neo_icon_well.dart` / `neo_device_tile.dart` / `glass_panel.dart` (+ call-sites in Dashboard/Remote).

## Stand van zaken (2026-09-06) — lees dit vóór een restyle

- Neu-cirkel + Qlink-backend blijven. **Geen** nieuw thema / geen Orbit-Filament-Comet / geen Nexus-orb. Dat experiment is verwijderd; gebruiker wil z’n eigen app.
- Tik = één commando (`Listener` pointer-up). Geen `setState` op pointer-down (dat at tikken; lamp bleef 100%).
- Live-status: bij connect **eerst loads** (`VGB#`), daarna keypads. Poll loads elke **4 s**. Na `VLB` opnieuw `requestLoad`. Parse `RGB#` / `LO`.
- `toggleLight` / `setLightLevel` gebruiken het **doelniveau**, niet `light.level` na een tussentijdse refresh.

## Dashboard / Remote visueel (actueel — 2026-09-06)

Niet special-casen op Evening/All Off: **elke** load- en macro-tegel gebruikt dezelfde cirkelknop.

### Achtergrond en tegel

- Scherm: `GlassBackdrop` graphiet `Neo.bg` `#26292E` / `Neo.bgTop` `#2B2F35`. Geen prism-foto, geen Lumen-void.
- Weer: **eigen** `GlassPanel` `#2E3239`. Kalender + memo: **samen** in één kader (6 px ertussen). Memo flex 4. Kaderhoogte 156, geen lege onderkant. Kalenderkop (13 px) op dezelfde lijn als weer-plaatsnaam.
- Load/macro-tegel: dekkend `Neo.surface` `#2E3239` (zelfde kleur als het kader). **Vaste hoogte 68** (toggle-maat) — ook macros en sliders. Raster-spatie **4 px**.

### Knop = cirkel (`neo_icon_well.dart`) — **SIZE LOCK 2026-09-06**

**NOOIT** `_aanGrow`, `size` (40), schaduwcijfers, face of OverflowBox wijzigen. Gebruiker heeft AAN/UIT uitgemeten tot ze gelijk waren. Eerdere “fixes” zonder OverflowBox deden niets (Flutter kneep AAN terug naar 40 px).

Licht **linksboven**. Layout-box altijd `size` 40. AAN tekent `diskSize = size * (21.5/18.5)` in een `OverflowBox` (zichtbare put = UIT).

| Staat | Schaduwen (`k = size/40`) — GEBLOKKEERD |
|-------|-----------|
| UIT (bol) | Licht TL `#4A515A` dist `2.8k` blur `1.0k`; donker BR `#0B0D10` dist `3.4k` blur `6.0k`; schaduw **achter** de schijf |
| AAN (put) | **Zelfde paar**, `inset: true`, `_aanGrow = 21.5/18.5` + OverflowBox — **niet** inverteren |

- Face `#32373E`. UIT: extra 1 px haarlijn in dezelfde face-kleur (scherp vs schaduw, geen tweede kleur). Tween **100 ms**. Geen `Transform.scale`. Geen extra put-padding. OverflowBox **moet** blijven.
- Heel de tegel is tikbaar; visuele press alleen op de cirkel (`pressed: active \|\| held`). Macros = pulse (280 ms hold), niet latched
- Pakket: `flutter_inset_shadow`

### Dim-slider + status (`neo_device_tile.dart`)

- Status **rechts uitgelijnd** op de naamregel: `Uit` / `Aan` / `70%`
- Slider (alleen `dimmable`) zit in dezelfde 68 px-tegel, verticaal **midden** tussen onderkant naam en onderkant cirkel (`height: 16`, `trackHeight: 2`)
- Toggle-LED 7 px op de naamregel als `showToggleLed`
- Insets: `_well=40`, `_labelGap=14`, `_endInset=12`, `_ledSize=7`, `_thumbRadius=4.5`

### Topbalk (`dashboard_top_band.dart`)

- Header: **geen** klok/datum meer — alleen Home, Live-LED, Indelen
- Datum **tussen de pijlen**: `sun 6 september 2026` = 13 px; uur blijft 15 px. Hele lijn wit/grijs `#B4B8BE`. Andere maand `october 2026` (13 px)
- Dagen 1–31 = 13 px. Raster 6 rijen tot de onderkant. Weer-forecast vult tot onderkant. Geen aparte onderlijnen.
- Zondag + Belgische feestdagen: `#C38578`. Vandaag-cirkel: `#CC5500` (wit cijfer). Geen wijziging van `_selectDay` / memo-logica
- Weer 5-dagen labels ook Engels (`weather_service.dart`)
- Titel **  Memo** (twee spaties naar rechts); linker padding = `Neo.radius`
- Kalender/memo-**logica** niet wijzigen bij een restyle (`_selectDay`, `_returnToDefaultMemo`, …)

## Remote-tab

- `home_shell.dart` index **1** = `PhoneRemoteScreen` (chips verborgen, Home-knop op het scherm)
- Volgorde: `dashboard.remoteOrder` + `remoteColumns` (1 of 2 rijen, bijna volle breedte, gap 4, pad 6). Indelen: sleep vrij naar een vak (zoals Dashboard), tik 1/2, Rij+
- Loads: `_LoadRow` → `NeoDeviceTile` (`compact: true`) — zichtbare dunne dim-slider of toggle-LED
- Macro’s: `_ScenePill` → dezelfde `NeoDeviceTile` (geen aparte knop)
- Long-press kleur = zelfde `tileColors` als Dashboard

## Dashboard-tab

- Tab naast Home; op Dashboard zijn de bovenste tab-chips verborgen (Home-knop op het scherm)
- **Topbalk** (`dashboard_top_band.dart`): **vast bovenaan, volle breedte**, los van het tile-raster
  - Weer eigen kader; kalender + memo samen (`GlassPanel` `#2E3239`)
  - Memo: vrij veld = boodschappenlijst (`memoNote`). Dagnotitie = afspraak (`dayMemos`, cirkel/neon-gloed op kalender).
  - Op **de dag zelf** van een bewaarde afspraak: memo toont die afspraak (niet de boodschappenlijst). **C** wist de afspraak → boodschappenlijst terug.
  - Andere dagen: tik dag → afspraak bewerken; ✓ bevestigt; na 30 s terug naar ruststand (`_returnToDefaultMemo`: vandaag-afspraak of lijst).
  - Internet nodig voor weer
  - Toggle aan/uit via Indelen → “Weer-balk”
- **Tile-raster** alleen lights/macros (+ lege cellen `empty` zodat elke kolom bruikbaar is)
  - Kolommen **1–6** (phone+tablet via `setDashboardColumnCount`)
  - Indelen: sleep naar cel / tik kolom 1…N / Rij+ / × weg
  - Persistent: `dashboardConfigJson` (`tileOrder`, `remoteOrder`, pins, weather, memo, `dayMemos`, `tileColors`, kolommen, `wallTabletMode`)
- Pins: Lights/Macros-tabs **of** Dashboard → Indelen → “Lights / macros”
- **Landscape-lock** op Dashboard-tab (`home_shell.dart`); andere tabs vrij draaien
- UI: `dashboard_screen.dart`, nav: `shell_nav.dart`
- Tegels: `NeoDeviceTile` (cirkel + slider/LED) — zie blok **Dashboard / Remote visueel**

### Vaste tablet / proximity (muur)

- Settings → **Vaste tablet (muur)** (`wallTabletMode`)
- Na **3 min** geen tik → standby: zwart vlak + analoge klok midden (`standby_analog_clock.dart`, ~40% korte zijde). Backlight **0.16** (niet 0 — anders is de klok onzichtbaar). Venster blijft wakker (wakelock) zodat de camera kan zien. Échte Android-slaap stopt de camera → proximity werkt dan niet.
- Camera **alleen in standby** (beweging, geen gezicht). Preview opacity 0 onder het klokvlak.
- Beweging of tik → backlight terug (−1), Dashboard + `connect()` naar IPE
- Code: `wall_tablet_presence.dart` + `MainActivity.kt`
- Packages: `camera`, `wakelock_plus`, `permission_handler:11.3.1` (niet 13+)

### Launcher-icoon

- Gewenst icoon: glanzende V (`assets/branding/vantage_app_icon.png`)
- Mipmaps: `tools/gen_launcher_icons.py` → `android/.../res/mipmap-*/ic_launcher*.png`
- Adaptive background: `#0A0A0A` in `values/colors.xml`

## Load Type / icoon (WebPoint-pariteit)

- Zelfde Type-lijst als WebPoint Object Properties (Blinds, Lamp, Fan, Television, …)
- UI: Lights → icoonknop (of long-press op aan/uit) → `icon_type_picker.dart`
- Mapping: `lib/src/ui/device_icons.dart` (Material icons)
- Persistent: `lightIconsJson` (lightKey → IconName); veld `LightDevice.iconType`

## Tooling (deze machine)

Typische paden (kunnen afwijken):

- Flutter: `D:\dev\flutter\bin`
- Android SDK: `D:\Android\Sdk`
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot`
- NDK: `27.1.12297006` (gezet in `android/app/build.gradle.kts`)

Build:

```bat
set PATH=D:\dev\flutter\bin;%PATH%
set ANDROID_HOME=D:\Android\Sdk
cd vantage-nvr-android
set JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot
flutter config --jdk-dir "%JAVA_HOME%"
flutter pub get
flutter build apk --release
copy /Y build\app\outputs\flutter-apk\app-release.apk "%USERPROFILE%\Desktop\vantage-nvr.apk"
```

AAR (niet in git): kopieer `ipclibrary_*.aar` naar `android/app/libs/` vanuit IvyIo android-app-sdk-demo.

APK-output:

- `build\app\outputs\flutter-apk\app-release.apk`
- Desktop **`vantage-nvr.apk`** / **`Vantage-NVR.apk`**
- Launcher-label: **Vantage NVR**
- Hoofd-app blijft apart: `vantage-control-android` → `vantage-control.apk`

`android/local.properties` moet `sdk.dir` en `flutter.sdk` bevatten (lokaal, niet committen als secrets/noise).

## Bekende issues / valkuilen

1. **Poort 3040 vs 3041** — verkeerde poort = “Could not Opening TCPIP” / geen bediening  
2. **Dubbele `Home.exe`** — poort 80 conflict; één WebPoint-instance  
3. **Eén TCP-sessie** — app + WebPoint tegelijk = flaky  
4. **Keypad alleen uit, niet aan** — vaak verkeerde VSW-vorm/timing op Dim-knoppen; check WebPoint-log `VSW# … 6`  
5. **Demo-macro’s** — zonder geconfigureerde load-actions gebeurt er niets zinvols  
6. **google_fonts** — haalt fonts online bij eerste run; offline first-run kan theme beïnvloeden  
7. **NDK** — incomplete NDK-map gaf eerder `CXX1101`; gebruik volledige NDK 27.x  
8. **permission_handler ≥13** — breekt Gradle (kotlin compilerOptions); blijf op **11.3.1**  
9. **Weer niet in tile-raster** — nooit opnieuw `weather`/`clock` als grid-tegel toevoegen  
10. **Muur-tablet** — zonder camera wekt beweging niet (tik wel). Geen systeem-slaap: dan stopt de camera.  
11. **Neu-cirkel SIZE LOCK** — `40` + `_aanGrow 21.5/18.5` + OverflowBox. Schaduw `2.8k/1.0k` + `3.4k/6.0k`. Face `#32373E`. **Nooit** herschalen of OverflowBox weghalen.  
12. **Tegelhoogte** — alles 68 px (toggle). Status rechts. Gap 4 px.  
13. **Tegel te donker / knop plat** — tegel `#2E3239`; cirkelface `#32373E`  
14. **Geen dim-wash** — geen `dimFill` over de tegel  
15. **Live vs UI** — als de lamp 100% is en de tegel UIT toont: refresh/poll, niet de knop omdraaien  
16. **Geen tabula-rasa redesign** — gebruiker heeft dat afgewezen; alleen gevraagde UI-tweaks
17. **FN8108W** — geen RTSP/ONVIF/CGI; alleen IvyIo. Loginfout **3** = verkeerde user/wachtwoord (`Result.USR_OR_PWD_ERR`).
18. **Kanaal wisselt niet** — `AndroidView` creationParams één keer; wissel via nieuwe surfaces + `nvrSelectedChannels`, niet alleen het cijferveld.
19. **Beeld gestretched** — native view vulde het hoge 2×5-vak; gebruik 16:9 cover, geen letterbox-balken.
20. **IvyIo-AAR ontbreekt** — build faalt zonder `android/app/libs/ipclibrary_*.aar`.
21. **Java 25 vs Gradle 8.12** — `flutter config --jdk-dir` naar JDK 17 (Microsoft hotspot op deze PC).
22. **Geen git tenzij gevraagd** — geen force-push, geen secrets (NVR-wachtwoord, wifi-PSK).

## Aanbevolen werkwijze voor latere AI’s

1. Lees dit bestand + `README.md`  
2. Bij protocolvragen: WebPoint-logs + `client.py` + dit protocol-blok  
3. Bij UI/state: `app_controller.dart` + `dashboard_config.dart` +  
   Remote → `phone_remote_screen.dart` · Dashboard → `dashboard_screen.dart` + `dashboard_top_band.dart`  
   Tegels/knop → `neo_device_tile.dart` + `neo_icon_well.dart` + `glass_panel.dart`  
4. Bij project/QLK: `qlk_importer.dart` / `project_importer.dart` + eventueel echte `.qlk` van de gebruiker  
5. Na codewijziging: `flutter analyze` + `flutter build apk --release`  
6. Lever **`vantage-nvr.apk`** naar Desktop. Hoofd-app niet mee-wijzigen tenzij gevraagd.  
7. Plan-bestanden onder `.cursor/plans/` zijn historisch; **deze repo-map is de bron van waarheid**  
8. **Nooit** een nieuwe Remote/kalender bouwen vanuit alleen de APK of een oude zip zonder `dashboard_top_band.dart` / `neo_device_tile.dart`

## Acceptatiechecklist (korte regressie)

- [ ] Connect Local LAN `192.168.1.33:3041` (WebPoint/QLink dicht)  
- [ ] Load dimmen/schakelen op Lights  
- [ ] Keypad: aan én uit (toggle) werkt herhaalbaar  
- [ ] Load/knop hernoemen blijft na herstart  
- [ ] QLK laden vult Lights/Keypads uit bestand  
- [ ] Macro/scene: lampen kiezen + niveaus + uitvoeren via VLB  
- [ ] Via-router profiel toont/gebruikt WAN-host + poort  
- [ ] APK-installatie toont naam **Vantage Remote** + glanzende V-launcher  
- [ ] Dashboard: weer-balk vast bovenaan; raster alleen lights/macros; kolommen 1–6  
- [ ] Header: geen klok/datum; datum 13 px + uur 15 px wit/grijs tussen pijlen  
- [ ] UIT-cirkel: 1 px haarlijn face-kleur; SIZE LOCK onaangeroerd  
- [ ] Remote Indelen: 1 of 2 rijen, vrij verslepen, bijna volle schermbreedte  
- [ ] Memo-titel twee spaties naar rechts in het kader met de kalender  
- [ ] Weer in eigen kader; kalender + memo samen; dagen 13 px; kader 156, geen lege onderkant    
- [ ] Kalender: andere maand toont `october 2026` tussen de pijlen  
- [ ] Kalender: tik andere dag → afspraak; dag-van-afspraak toont afspraak i.p.v. boodschappenlijst; C → lijst terug  
- [ ] Remote-tab: zelfde namen/kleuren/dim-modus als Dashboard  
- [ ] Tegels: zelfde hoogte als toggle; status rechts; slider midden naam↔cirkel; kleur `#2E3239`  
- [ ] Cirkel SIZE LOCK: AAN en UIT dezelfde zichtbare mm; OverflowBox + `_aanGrow` onaangeroerd  
- [ ] Indelen: lege cellen + slepen/kolomkeuze  
- [ ] Vaste tablet: 3 min → analoge klok midden + backlight 0.16, beweging wekt (+ connect-poging)  
- [ ] Live: fysieke 100% = tegel Aan/100% (poll)  
- [ ] NVR: LAN-zoek + login (zelfde wachtwoord als Foscam-app)  
- [ ] NVR: balk CAM 1–4 / alle; beeld 16:9 zonder stretch  
- [ ] Lights: 16 IPE-loads; tik naam → enc/mod/load; AAN/UIT via IPE
