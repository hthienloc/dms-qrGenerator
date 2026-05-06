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
                text: "Generation & Privacy"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "clearQrOnClose"
                label: "Clear QR Code on Close"
                description: "Automatically clear the text and QR code when you close the popout."
                defaultValue: true
            }

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

            StringSetting {
                settingKey: "savePath"
                label: "Save Directory"
                description: "Where to save exported QR code images."
                placeholder: "~/Pictures/QRCodes"
                defaultValue: "~/Pictures/QRCodes"
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
