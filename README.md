<div align="center">

# Ski Nerd Lock Screen 1.0

**Your mountain cameras, one glance away.**

Native macOS screen saver · Four configurable cameras · Snow stakes · Weather

[![Release](https://img.shields.io/github/v/release/MK420-max/ski-nerd-lock-screen)](https://github.com/MK420-max/ski-nerd-lock-screen/releases/latest)
![macOS](https://img.shields.io/badge/macOS-26%2B-111827?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-arm64-64748b)
![Languages](https://img.shields.io/badge/UI-English_%2F_简体中文-3b82f6)
[![License](https://img.shields.io/badge/license-MIT-22c55e)](LICENSE)

[Download 1.0](https://github.com/MK420-max/ski-nerd-lock-screen/releases/tag/v1.0) · [中文说明](README.zh-CN.md) · [Configuration](#configure-your-cameras) · [Known limits](#known-limits)

![Illustrated interface guide](docs/images/interface-guide.png)

</div>

> The guide above is an AI-generated illustration. The screenshots below are captured from the native app with generic account placeholders. Example weather and images change over time.

## At a glance

| Feature | What it does |
| --- | --- |
| Four large camera views | Two configurable resorts, with two cameras in each connected glass row |
| Your own camera sources | Public HTTPS HLS streams, YouTube/CamStreamer pages, or timed image snapshots |
| Snow-stake cameras | A smaller central snapshot for each resort; unavailable sources show **Offline · Retrying** |
| Weather | Per-camera temperature at its configured elevation, plus 24-hour model snow/rain forecasts |
| Desktop background | Uses the built-in display’s current desktop wallpaper across both displays |
| Compact settings | English / Simplified Chinese / system language, camera names, elevations, URLs and white logos |
| Lock-screen layout | Leaves the system clock and password area to macOS; no password collection or custom authentication |

### Native preview

![Native English preview](docs/images/preview-en.png)

### Camera settings

<table><tr>
<td width="50%"><img src="docs/images/settings-en.png" alt="English camera settings"/></td>
<td width="50%"><img src="docs/images/settings-zh.png" alt="中文摄像头设置"/></td>
</tr></table>

## Install

1. Download **Ski-Nerd-Lock-Screen-1.0-macOS-arm64.zip** from [Releases](https://github.com/MK420-max/ski-nerd-lock-screen/releases/tag/v1.0) and extract it completely.
2. Run **Install.command**. It installs the settings app, screen saver and two per-user background components. Python and Node are bundled; no Homebrew or developer tools are required to run the release.
3. Open **Ski Nerd Lock Screen** from your user Applications folder.
4. In **System Settings → Wallpaper → Screen Saver**, choose **Mountain Cams**. The screen saver keeps this internal name for compatibility.
5. Save your settings, check the preview, then lock your Mac normally.

**Requirements:** Apple silicon Mac, macOS 26 or later, and an internet connection. The shipped build is ad-hoc signed and **not notarized**. macOS may require you to review it in **Privacy & Security** before opening. Do not disable Gatekeeper. Intel builds are not included.

## Configure your cameras

Open the app, or press **⌘,** from a preview. Select **Top row** or **Bottom row**:

1. Enter a resort name; optionally choose a transparent PNG/PDF logo.
2. Enter both latitude and longitude for resort weather, or leave both blank.
3. Set each camera name and elevation in metres.
4. Choose **Live** for a public direct `.m3u8`, YouTube or CamStreamer URL; choose **Snapshot** for a direct public HTTPS image URL.
5. Optionally add a snow-stake image URL, then select **Save & Preview**.

Snapshots refresh every 60 seconds. Live feeds reconnect automatically. Missing cameras stay visibly unconfigured; a failed feed is never silently replaced by a different camera. Default presets are Whistler and Cypress. There is no global camera search or login/cookie support.

**Language:** choose **English**, **简体中文** or **System / 系统** and save. Language applies to the settings, preview and screen saver. User-entered camera and resort names remain unchanged. macOS-owned dialogs follow the Mac’s language.

| Shortcut | Action |
| --- | --- |
| ⌘, | Camera settings |
| ⌘P | Open preview |
| ⇧⌘D | Preview on all connected displays |
| ⌘Q | Quit the settings/preview app |

## Privacy

- No account, analytics, calendar access, password capture or media recording.
- Camera settings remain in `~/Library/Application Support/MountainCams/resorts.json`; custom logos stay in the same folder.
- The resolver listens only on `127.0.0.1:48764`. It contacts configured public providers to find playable streams.
- Cameras and Open-Meteo receive ordinary network requests. Resort coordinates are sent to Open-Meteo for forecasts.
- This repository and download contain **no personal configuration, local usernames, absolute home paths, private logs, tokens or cached camera captures**. Default endpoints are public resort sources. Screenshots use a generic account placeholder.

## Known limits

- The city weather strip is **Burnaby, BC**, and preview date/time uses **America/Vancouver** in 1.0. Resort coordinates and elevations are configurable. The real system clock remains controlled by macOS.
- Weather is an Open-Meteo model estimate, not a resort weather-station observation. Rain/snow values cover the next 24 forecast hours.
- The Cypress snow-stake endpoint was unavailable during verification. Its offline/retry state is intentional; you can replace its URL.
- Streams can be unavailable, geoblocked or changed by their operators. Only public unauthenticated sources are supported.
- Four video sources per display require power and bandwidth. macOS sleep, display power saving and network availability still apply.
- The accepted lock layout was checked on one Apple silicon Mac with built-in and external displays. Other resolutions and future macOS lock-screen changes need their own check. This app does not modify system authentication.

## Build from source

Requires Xcode Command Line Tools and macOS 26+ SDK:

```sh
zsh src/build.sh
zsh scripts/test.sh
```

Native bundles are written to `build/`. The packaged resolver is built with PyInstaller from `src/Resolver.py` and the pinned `src/requirements.txt`; the release includes its runtime and Node. To rebuild the full ZIP, install `scripts/requirements-release.txt` in a Python 3.12 environment, have Node on PATH, then run `zsh scripts/package.sh`. See [release verification](docs/VERIFICATION.md) and [third-party notices](THIRD_PARTY_NOTICES.md).

## Project layout

```text
src/             Native AppKit views, settings, playback and local resolver
scripts/         Build checks and per-user installer
docs/images/     Generated guide and redacted native screenshots
```

## Credits & license

Source code is licensed under [MIT](LICENSE). Resort names, logos, live media, wallpaper and third-party dependencies retain their respective rights. This is an independent project, unaffiliated with Apple or the camera/resort operators. See [third-party notices](THIRD_PARTY_NOTICES.md).
