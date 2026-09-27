# START HERE — AI / andere PC

Dit is de **draagbare eenheid** voor het **QLink Vantage dashboard** (tablet-app) op **elke PC**.

**Huidige handoff-zip:** `next ai agent.zip` (Desktop). Daarin zit `vantage-control-android/` + deze gidsen.

**SIZE LOCK:** cirkel AAN/UIT in `neo_icon_well.dart` nooit herschalen (`_aanGrow` + OverflowBox).

## PDF-handleiding (NL + EN)

- `docs/README-AI-NL.md` / `docs/README-AI-EN.md`
- Eventueel `docs/README-AI-NL-EN.pdf` als die aanwezig is

## Wat kopiëren?

Kopieer of zip de hele map **`vantage-control-android/`** (broncode).  
**Niet** alleen de `.apk`.

Minimaal nodig:

- `AGENTS.md` ← AI leest dit **eerst** (o.a. stand van zaken 2026-09-06)
- `README.md`
- `lib/` — o.a. `neo_icon_well.dart`, `neo_device_tile.dart`, `glass_panel.dart`, `dashboard_top_band.dart`, `wall_tablet_presence.dart`
- `android/` — o.a. `MainActivity.kt` (backlight-kanaal)
- `assets/`
- `pubspec.yaml` (`flutter_inset_shadow`, `camera`, `wakelock_plus`, `permission_handler:11.3.1`)
- dit bestand `START_HERE.md`

Niet nodig (weglaten in de zip):

- `build/`
- `.dart_tool/`
- `android/.gradle/`, `android/local.properties`

## Opdracht aan de AI (plak dit)

```
Lees eerst AGENTS.md en START_HERE.md in vantage-nvr-android/.
Dit is het QLink Vantage dashboard (Flutter) voor IPE VCommand poort 3041.
Bron van waarheid: lib/ (niet de APK).
Remote-tab = phone_remote_screen.dart.
Dashboard = dashboard_screen.dart + dashboard_top_band.dart
(memoNote, dayMemos, setDashboardDayMemo / setMemoForDay, _selectDay, _returnToDefaultMemo).
Remote en Dashboard delen tileColors en apparaatinstellingen.
Tegels: neo_device_tile.dart + neo_icon_well.dart.
  CIRKEL SIZE LOCK 2026-09-06: size 40, AAN OverflowBox × 21.5/18.5,
  schaduw 2.8k/1.0k licht + 3.4k/6.0k donker, face #32373E, AAN=inset.
  NOOIT grootte/OverflowBox/_aanGrow wijzigen (anders wordt AAN weer 18,5 mm).
  tween 100 ms, hoogte tegel 68, status rechts, slider midden naam↔cirkel.
  Weer eigen kader; kalender+memo samen #2E3239.
  Kalender: datum 13 px + uur 15 px, hele lijn wit/grijs.
  Zondag + BE-feestdagen #C38578; vandaag-cirkel #CC5500.
  UIT-cirkel: 1 px haarlijn, zelfde kleur als de schijf (niet groter maken).
  Remote Indelen: 1 of 2 rijen, vrij verslepen, bijna volle breedte.
Kalender/memo/weer-logica, VLB-fade en protocol niet wijzigen bij een restyle.
Geen tabula-rasa redesign, geen tweede app-id (vantage_muur).
applicationId = com.vantage.control.vantage_remote, label Vantage Remote.
Lever een nieuwe release-APK als vantage-control.apk op de Desktop.
```

## APK vs bron

| Bestand | Rol |
|---------|-----|
| `vantage-control.apk` | Installeren op de tablet (Vantage Remote) |
| `vantage-control-android/` of `next ai agent.zip` | AI + Flutter verder ontwikkelen |

De gids zit ook in `assets/docs/` (mee in de APK), maar **zonder** `lib/` kun je niet verder programmeren.
