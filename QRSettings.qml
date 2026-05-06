import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "qr-generator"

    StyledText {
        width: parent.width
        text: "QR Generator Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledRect {
        width: parent.width
        height: contentColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Generation"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "autoClipboard"
                label: "Auto-generate from Clipboard"
                description: "Automatically update the QR code whenever you copy new text."
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "keepQrOnClose"
                label: "Keep QR Code on Close"
                description: "If disabled, the QR code will be cleared when you close the popout for privacy."
                defaultValue: false
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
    }

    StyledRect {
        width: parent.width
        height: requirementsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: requirementsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingS

            StyledText {
                text: "System Requirements"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "This plugin requires 'qrencode' to be installed on your system.\n\nFedora: sudo dnf install qrencode\nArch: sudo pacman -S qrencode"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }
    }
}
