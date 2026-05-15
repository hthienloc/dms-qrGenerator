import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "../dms-common"

PluginSettings {
    id: root
    pluginId: "qrGenerator"

    PluginHeader {
        title: "QR Generator Settings"
    }

    SettingsCard {
        SectionTitle { text: "Generation & Privacy" }

        ToggleSetting {
            settingKey: "clearQrOnClose"
            label: "Clear QR Code on Close"
            description: "Automatically clear the text and QR code when you close the popout for privacy."
            defaultValue: true
        }

        SelectionSetting {
            settingKey: "qrSize"
            label: "QR Code Size"
            description: "The resolution/scale of the generated QR code."
            options: [
                { label: "Small", value: "3" },
                { label: "Medium", value: "6" },
                { label: "Large", value: "10" }
            ]
            defaultValue: "6"
        }
    }

    SettingsCard {
        SectionTitle { text: "Display & UI" }

        SelectionSetting {
            settingKey: "pillStyle"
            label: "Bar Display Style"
            description: "Choose how the plugin is displayed on the bar."
            options: [
                { label: "Icon Only", value: "icon" },
                { label: "Icon + Text", value: "text" }
            ]
            defaultValue: "icon"
        }

        ToggleSetting {
            settingKey: "showHints"
            label: "Show Hints"
            description: "Display helpful usage tips and shortcuts at the bottom of the popout."
            defaultValue: true
        }
    }

    SettingsCard {
        SectionTitle { text: "Installation" }

        InfoText {
            text: "Install the required package:"
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: [
                    { cmd: "sudo dnf install qrencode", label: "Fedora" },
                    { cmd: "sudo pacman -S qrencode", label: "Arch Linux" },
                    { cmd: "sudo apt install qrencode", label: "Debian/Ubuntu" },
                    { cmd: "sudo zypper install qrencode", label: "openSUSE" }
                ]

                delegate: CopyBox {
                    label: modelData.label
                    text: modelData.cmd
                }
            }
        }
    }
}
