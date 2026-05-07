# QR Generator Plugin

A dedicated QR code generator plugin for [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell).

<img src="screenshot.png" width="400" alt="Screenshot">

## Installation

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
git clone https://github.com/hthienloc/dms-qr-generator ~/.config/DankMaterialShell/plugins/qr-generator
```

Then in DMS: **Settings (Meta+,)** → **Plugins** → **Scan for Plugins** → Enable **QR Generator**.

### System Requirements

This plugin requires `qrencode` to generate images and `wl-clipboard` (or `xclip`) for clipboard support.

**Fedora:**
```bash
sudo dnf install qrencode wl-clipboard xclip
```

**Arch:**
```bash
sudo pacman -S qrencode wl-clipboard xclip
```

## Features

- **Wi-Fi Sharing**: Instantly share your current Wi-Fi connection. One click fetches your active SSID and Password (using `nmcli`) and generates a standard Wi-Fi QR code for guests.
- **Real-time Generation**: QR code updates instantly as you type.
- **Clipboard Integration**:
    - **From Clipboard**: Quickly generate a QR code from your current clipboard content.
    - **Right-click Shortcut**: Right-click the bar icon to automatically pull from clipboard and open the generator.
- **Export Options**:
    - **Save Image**: Export the QR code as a PNG to your preferred directory (default: `~/Pictures/QRCodes`).
    - **Copy Image**: Copy the generated QR image directly to your clipboard for easy sharing.
- **Privacy Focus**: Automatically clears content when the popout is closed (configurable).
- **Customizable Appearance**:
    - **Bar Display**: Choose between "Icon Only" or "Icon + Text".
    - **Dynamic Colors**: Icon changes color when active content is present.
- **Standardized Naming**: Exported files follow the `qr_YYYY-MM-DD_HHMMSS.png` format.

## Structure

```
dms-qr-generator/
├── QRWidget.qml         # Main logic and UI
├── QRSettings.qml       # Settings interface
├── plugin.json          # Plugin manifest
├── LICENSE
└── README.md
```

## Development

Built with QML using the DMS plugin API. Uses system CLI tools via `Proc` for image generation and clipboard handling.

## License

GPLv3 - See [LICENSE](LICENSE)
