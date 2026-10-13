# FeatherStat 🪶

A featherweight (~16 MB RAM) macOS menu bar system resource monitor written in pure Swift.

![macOS 12.0+](https://img.shields.io/badge/macOS-12.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Ultra-low RAM footprint**: Uses only ~16 MB of memory (no Electron, no web views, no heavy frameworks).
- **Direct kernel APIs**:
  - **RAM**: Mach kernel `host_statistics64` & `sysctl`
  - **CPU**: Mach host load info (`HOST_CPU_LOAD_INFO`)
  - **Network**: BSD `getifaddrs` packet counters for real-time down/up throughput
  - **GPU**: Direct IOKit `IOAccelerator` device utilization
- **Customizable Modules**: Toggle RAM, Network, CPU, and GPU stats independently from the menu.
- **Configurable Refresh Rates**: Choose between 1s, 2s, or 3s intervals.
- **Quick Access**: Direct shortcut to macOS Activity Monitor.

---

## Installation

### Option 1: Download Prebuilt DMG
1. Download `FeatherStat.dmg` from the [Releases](https://github.com) page.
2. Open the DMG and drag **FeatherStat** to your `/Applications` folder.
3. Launch FeatherStat.

> **Note for macOS Gatekeeper:**
> Because this is an open-source app built without an Apple Developer certificate, macOS may show a prompt stating that the developer cannot be verified.
> To allow it:
> - **Right-click** (or Control-click) `FeatherStat.app` in `/Applications` and select **Open**, then click **Open**.
> - Or run in Terminal:
>   ```bash
>   xattr -cr /Applications/FeatherStat.app
>   ```

### Option 2: Build from Source

#### Prerequisites
- macOS 12.0 or newer
- Xcode Command Line Tools installed (`xcode-select --install`)

#### Build
```bash
git clone https://github.com/<your-username>/FeatherStat.git
cd FeatherStat
./build.sh
```

The script compiles the native binary into `build/FeatherStat.app` and packages `build/FeatherStat.dmg`.

---

## How It Works

Many macOS system monitors consume hundreds of megabytes of RAM and noticeable CPU cycles simply monitoring the system. **FeatherStat** is designed with minimalism as a first principle:

- It runs as a lightweight `LSUIElement` accessory app (no Dock icon, status bar only).
- Metric samples are gathered via direct synchronous C/Mach system calls with zero subprocess spawning (`top`, `vm_stat`, or shell scripts).
- Idle overhead is negligible.

---

## License

This project is licensed under the [MIT License](LICENSE).
