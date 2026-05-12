import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "qrGenerator"

    StyledText {
        width: parent.width
        text: "QR Generator Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    // --- Generation & Privacy Section (High Priority) ---
    StyledRect {
        width: parent.width
        height: genColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: genColumn
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
    }

    // --- Display & UI Section (Lower Priority) ---
    StyledRect {
        width: parent.width
        height: displayColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: displayColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Display & UI"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
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

            ToggleSetting {
                settingKey: "showHints"
                label: "Show Accessibility Hints"
                description: "Display helpful usage tips at the bottom of the popout."
                defaultValue: true
            }
        }
    }

    // --- Requirements Section ---
    StyledRect {
        width: parent.width
        height: installColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: installColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Installation"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "Install the required package:"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
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

                    delegate: Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: Theme.surfaceVariantText
                        }

                        Rectangle {
                            width: parent.width
                            height: Math.max(40, cmdRow.implicitHeight + 16)
                            color: Theme.surfaceContainerHigh
                            radius: 4

                            Row {
                                id: cmdRow
                                width: parent.width - 16
                                anchors.centerIn: parent
                                spacing: 8

                                StyledText {
                                    width: parent.width - 32
                                    text: modelData.cmd
                                    font.family: "Monospace"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.secondary
                                    wrapMode: Text.Wrap
                                }

                                DankButton {
                                    width: 24
                                    height: 24
                                    iconName: "content_copy"
                                    backgroundColor: "transparent"
                                    textColor: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        Proc.runCommand("copy-cmd", ["wl-copy", "--", modelData.cmd], function() {
                                            ToastService.showInfo("Copied to clipboard");
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
