# QLink Vantage dashboard (Android)

Tablet-dashboard voor een **Vantage Q**-installatie die je programmeert met **QLink** (`.qlk`) en bedient via **WebPoint** / **IPE1000-P**.

Deze app is een moderne Flutter-client op **VCommand TCP 3041** — niet QLink zelf (dat blijft **3040**, programmeren). Je laadt hetzelfde `.qlk` in de UI, schakelt loads (`VLB`) en keypads (`VSW#`), en legt lights/macros op een **Dashboard** + **Remote**.

Optioneel in deze build: **Foscam FN8108W** live-beeld via IvyIo (aparte `applicationId` **Vantage NVR**). De hoofd-app zonder camera is `vantage-control-android` → `vantage-control.apk`.

Zoektermen: QLink, Vantage Q, Vantage Controls, IPE1000-P, WebPoint, `.qlk`, Infusion (niet dit protocol).

AI / protocol: **[AGENTS.md](AGENTS.md)**.

## Dashboard

- Vaste topbalk: weer, kalender, memo (niet als tegel)
- Raster lights + macros, kolommen 1–6, lege cellen, slepen in Indelen
- Neu-cirkel AAN/UIT + dim-slider of toggle
- Remote-tab (telefoon): dezelfde loads/kleuren
- QLK laden in Settings (UI only — programmeert de Master niet)
- Local LAN of via-router (port forward naar IPE:3041)
- Optioneel muur-tablet (standby-klok + beweging)

## Features

- Lights (`VLB`) and keypads (`VSW#`)
- Phone-side macros (opeenvolgende `VLB`)
- Schedules / temperature / time screens
- Bundled WebPoint export (`assets/project`) + eigen `.qlk`
- **Local LAN** and **Via router**

## Verbinden wanneer de IPE aan de wifi-router hangt

De telefoon verbindt met de **IPE**, niet met de router-UI. QLink en WebPoint **dicht** (één TCP-sessie).

### A) Thuis — zelfde wifi

| Instelling in app | Waarde |
|-------------------|--------|
| Profiel | **Local LAN** |
| Host | `192.168.1.33` |
| Poort | `3041` (VCommand) |

### B) Buitenshuis — via router port forward

1. IPE vast IP: `192.168.1.33`
2. Router → Port Forward (TCP) → `192.168.1.33:3041`
3. App-profiel **Via router**: WAN/DynDNS + externe poort

Veiliger: VPN naar huis, daarna **Local LAN**.

## Build / sideload

```bat
set PATH=D:\dev\flutter\bin;%PATH%
cd vantage-nvr-android
flutter pub get
flutter build apk --release
```

IvyIo-AAR (`ipclibrary_*.aar` uit [android-app-sdk-demo](https://github.com/IVYIoT/android-app-sdk-demo) `app/libs`) in `android/app/libs/` voor NVR-beeld.

APK → Desktop `vantage-nvr.apk`. Label: **Vantage NVR** (dashboard + camera).

## Notes

- Bedienen: VCommand **3041**. QLink programmeren: **3040**.
- QLK-import vult de dashboard-UI; flash naar de Master blijft QLink.
- Macro / schedule / thermostat op de controller: best-effort; Lights en Keypads zijn bewezen.
