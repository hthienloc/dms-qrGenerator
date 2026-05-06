import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property bool clearQrOnClose: pluginData.clearQrOnClose ?? true
    readonly property string pillStyle: pluginData.pillStyle || "icon"
    readonly property string savePath: pluginData.savePath || "~/Pictures/QRCodes"
    readonly property string qrSize: pluginData.qrSize || "6"
    readonly property bool showHints: pluginData.showHints ?? true
    
    property string currentText: ""
    property string qrImagePath: "file:///tmp/dms-qr.png"
    property string cacheBuster: ""
    property var manualInputInput: null
    property var activePopoutReference: null

    function clearQR() {
        currentText = "";
        cacheBuster = "";
        if (manualInputInput) manualInputInput.text = "";
    }

    function generateQR(text) {
        if (!text) return;
        currentText = text.trim();
        
        // Use qrencode to generate the image
        Proc.runCommand(
            "generate-qr",
            ["qrencode", "-s", root.qrSize, "-o", "/tmp/dms-qr.png", currentText],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    cacheBuster = Date.now().toString();
                } else {
                    console.error("Failed to generate QR, exit code:", exitCode);
                }
            },
            0
        )
    }

    function saveImage() {
        if (!root.cacheBuster) return;
        
        // Use a standardized filename: qr_YYYY-MM-DD_HHMMSS.png
        const cmd = "DIR=\"" + root.savePath + "\"; " +
                    "mkdir -p \"$DIR\"; " +
                    "FILENAME=\"qr_$(date +%Y-%m-%d_%H%M%S).png\"; " +
                    "cp /tmp/dms-qr.png \"$DIR/$FILENAME\"";
        
        Proc.runCommand(
            "export-qr",
            ["sh", "-c", cmd],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    ToastService.showInfo("Saved to " + root.savePath);
                } else {
                    ToastService.showError("Failed to save image.");
                }
            },
            0
        )
    }

    function copyImageToClipboard() {
        if (!root.cacheBuster) return;
        
        Proc.runCommand(
            "copy-qr-image",
            ["sh", "-c", "wl-copy < /tmp/dms-qr.png || xclip -selection clipboard -t image/png -i /tmp/dms-qr.png"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    ToastService.showInfo("QR Image copied to clipboard!");
                } else {
                    ToastService.showError("Failed to copy image to clipboard.");
                }
            },
            0
        )
    }

    function copyToClipboard(text) {
        Proc.runCommand(
            "clipboard-copy",
            ["sh", "-c", "echo -n \"" + text + "\" | wl-copy || echo -n \"" + text + "\" | xclip -selection clipboard"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    ToastService.showInfo("Text copied to clipboard!");
                }},
            0
        )
    }

    pillRightClickAction: () => {
        // Fetch clipboard and generate QR before opening popout
        Proc.runCommand(
            "right-click-paste",
            ["sh", "-c", "wl-paste --no-newline || xclip -selection clipboard -o"],
            (stdout, exitCode) => {
                if (exitCode === 0 && stdout !== "") {
                    root.currentText = stdout;
                    root.generateQR(stdout);
                    if (root.manualInputInput) root.manualInputInput.text = stdout;
                }
                
                // Only trigger (toggle) if not already visible
                if (!root.activePopoutReference || !root.activePopoutReference.shouldBeVisible) {
                    root.triggerPopout();
                }
            },
            0
        )
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "qr_code_2"
                size: Theme.iconSizeSmall
                color: root.cacheBuster !== "" ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: "QR"
                font.pixelSize: Theme.fontSizeMedium
                color: root.cacheBuster !== "" ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.pillStyle === "text"
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingS
            DankIcon {
                name: "qr_code_2"
                size: Theme.iconSizeSmall
                color: root.cacheBuster !== "" ? Theme.primary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        FocusScope {
            id: contentFocusScope
            width: parent ? parent.width : 0
            implicitHeight: mainContent.implicitHeight
            focus: true

            property var parentPopout: null
            onParentPopoutChanged: root.activePopoutReference = parentPopout

            Connections {
                target: parentPopout
                function onOpened() {
                    Qt.callLater(() => {
                        if (root.manualInputInput) root.manualInputInput.forceActiveFocus();
                    });
                }
            }

            PopoutComponent {
                id: mainContent
                width: parent.width
                headerText: "QR Generator"
                detailsText: ""
                showCloseButton: true

                Component.onDestruction: {
                    if (root.clearQrOnClose) {
                        root.clearQR();
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingL
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.cacheBuster !== "") {
                                root.copyImageToClipboard();
                            }
                            event.accepted = true;
                        }
                    }

                    // QR Display Area
                    StyledRect {
                        width: 220
                        height: 220
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "white"
                        radius: Theme.cornerRadiusSmall
                        
                        Image {
                            id: qrImage
                            anchors.fill: parent
                            anchors.margins: 10
                            source: root.cacheBuster ? root.qrImagePath + "?t=" + root.cacheBuster : ""
                            fillMode: Image.PreserveAspectFit
                            visible: root.cacheBuster !== ""
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: "Ready to generate"
                            color: "#333"
                            visible: root.cacheBuster === ""
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    // Input & Actions Area
                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankTextField {
                            id: manualInput
                            width: parent.width
                            placeholderText: "Type or paste text here..."
                            showClearButton: true
                            focus: true
                            Component.onCompleted: {
                                root.manualInputInput = manualInput;
                                if (root.currentText !== "") {
                                    manualInput.text = root.currentText;
                                }
                            }
                            onTextEdited: {
                                if (text !== "")
                                    root.generateQR(text);
                            }
                            onEditingFinished: {
                                if (text !== "")
                                    root.generateQR(text);
                            }
                            onTextChanged: {
                                if (text === "") {
                                    root.currentText = "";
                                    root.cacheBuster = "";
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            
                            DankButton {
                                text: "Copy Image"
                                width: (parent.width - Theme.spacingS) / 2
                                iconName: "content_copy"
                                backgroundColor: Theme.secondary
                                enabled: root.cacheBuster !== ""
                                onClicked: root.copyImageToClipboard()
                            }

                            DankButton {
                                text: "Save Image"
                                width: (parent.width - Theme.spacingS) / 2
                                iconName: "save"
                                backgroundColor: Theme.primary
                                enabled: root.cacheBuster !== ""
                                onClicked: root.saveImage()
                            }
                        }
                    }
                    
                    StyledText {
                        text: "Hint: [Enter] to copy QR. Right-click bar icon to pull from clipboard."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        visible: root.showHints
                    }                }
            }
        }
    }

    popoutWidth: 350
    popoutHeight: {
        let h = (root.manualInputInput && root.manualInputInput.text !== "") ? 460 : 430;
        return root.showHints ? h : h - 30;
    }
}
