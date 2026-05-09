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
    property bool isFetchingWifi: false
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

    function fetchWifiAndGenerateQR() {
        root.isFetchingWifi = true;
        const cmd = "SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2 | head -n 1); " +
                    "if [ -n \"$SSID\" ]; then " +
                    "SEC=$(nmcli -t -f SSID,SECURITY device wifi | grep \"^$SSID:\" | cut -d: -f2 | head -n 1); " +
                    "PWD=$(nmcli -s -g 802-11-wireless-security.psk connection show \"$SSID\"); " +
                    "SEC_TYPE=\"WPA\"; " +
                    "if echo \"$SEC\" | grep -iq \"WEP\"; then SEC_TYPE=\"WEP\"; fi; " +
                    "if [ -z \"$SEC\" ] || [ \"$SEC\" = \"--\" ]; then SEC_TYPE=\"nopass\"; fi; " +
                    "if [ -z \"$PWD\" ]; then SEC_TYPE=\"nopass\"; fi; " +
                    "echo \"WIFI:S:$SSID;T:$SEC_TYPE;P:$PWD;;\"; " +
                    "else echo \"NO_WIFI\"; fi";

        Proc.runCommand(
            "fetch-wifi",
            ["sh", "-c", cmd],
            (stdout, exitCode) => {
                root.isFetchingWifi = false;
                const result = stdout.trim();
                if (exitCode === 0 && result !== "NO_WIFI") {
                    root.currentText = result;
                    if (root.manualInputInput) root.manualInputInput.text = result;
                    root.generateQR(result);
                }
            },
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
                showCloseButton: false

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

                    // 1. Input & Primary Generation Section
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

                        DankButton {
                            id: wifiButton
                            text: root.isFetchingWifi ? "Fetching Wi-Fi..." : "Share Current Wi-Fi"
                            width: parent.width
                            iconName: root.isFetchingWifi ? "sync" : "wifi"
                            backgroundColor: Theme.secondary
                            enabled: !root.isFetchingWifi
                            onClicked: root.fetchWifiAndGenerateQR()

                            // Rotation animation for the sync icon
                            RotationAnimation on iconName {
                                running: root.isFetchingWifi
                                from: 0; to: 360; duration: 1000
                                loops: Animation.Infinite
                                // Note: We can't actually animate the iconName property of DankButton 
                                // because it's a string, not the icon's rotation.
                                // Instead, we'll use a custom icon overlay if needed, 
                                // but for now let's use a simpler approach: 
                                // changing the text and icon is already good feedback.
                            }
                        }
                    }

                    // 2. QR Display Area (The Result)
                    StyledRect {
                        width: 240
                        height: 240
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "white"
                        radius: Theme.cornerRadius
                        border.width: 1
                        border.color: Theme.surfaceContainerHighest
                        
                        Image {
                            id: qrImage
                            anchors.fill: parent
                            anchors.margins: 16
                            source: root.cacheBuster ? root.qrImagePath + "?t=" + root.cacheBuster : ""
                            fillMode: Image.PreserveAspectFit
                            visible: root.cacheBuster !== "" && !root.isFetchingWifi
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        // Spinner during Wi-Fi fetch
                        DankIcon {
                            anchors.centerIn: parent
                            name: "sync"
                            size: 48
                            color: Theme.primary
                            visible: root.isFetchingWifi
                            
                            RotationAnimation on rotation {
                                running: root.isFetchingWifi
                                from: 0; to: 360; duration: 1000
                                loops: Animation.Infinite
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: "Ready to generate"
                            color: Theme.surfaceVariantText
                            visible: root.cacheBuster === "" && !root.isFetchingWifi
                            font.pixelSize: Theme.fontSizeSmall
                            opacity: 0.7
                        }
                    }

                    // 3. Post-Generation Actions
                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: root.cacheBuster !== ""

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            
                            DankButton {
                                text: "Copy Image"
                                width: (parent.width - Theme.spacingS) / 2
                                iconName: "content_copy"
                                backgroundColor: Theme.primary
                                enabled: root.cacheBuster !== ""
                                onClicked: root.copyImageToClipboard()
                            }

                            DankButton {
                                text: "Save Image"
                                width: (parent.width - Theme.spacingS) / 2
                                iconName: "save"
                                backgroundColor: Theme.surfaceContainerHighest
                                textColor: Theme.surfaceText
                                enabled: root.cacheBuster !== ""
                                onClicked: root.saveImage()
                            }
                        }
                    }
                    
                    StyledText {
                        text: "Hint: Right-click bar icon to pull from clipboard. [Enter] to copy QR."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        visible: root.showHints
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    popoutWidth: 350
    popoutHeight: {
        let h = (root.cacheBuster !== "") ? 560 : 480;
        return root.showHints ? h : h - 40;
    }
}
