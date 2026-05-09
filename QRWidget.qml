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
    property bool isFetchingWifi: false
    property var manualInputInput: null
    property var activePopoutReference: null

    // Dual-buffering to prevent flickering
    property bool useImageA: true
    property string pathA: "/tmp/dms-qr-a.png"
    property string pathB: "/tmp/dms-qr-b.png"
    property string sourceA: ""
    property string sourceB: ""

    Timer {
        id: debounceTimer
        interval: 200
        repeat: false
        onTriggered: root.generateQRInternal(root.currentText)
    }

    function clearQR() {
        currentText = "";
        sourceA = "";
        sourceB = "";
        if (manualInputInput) manualInputInput.text = "";
    }

    function generateQR(text) {
        if (!text || text.trim() === "") {
            currentText = "";
            sourceA = "";
            sourceB = "";
            return;
        }
        currentText = text;
        debounceTimer.restart();
    }

    function generateQRInternal(text) {
        if (!text) return;
        const trimmed = text.trim();
        if (trimmed === "") return;
        
        // Generate to the "inactive" path
        const targetPath = root.useImageA ? root.pathB : root.pathA;
        
        Proc.runCommand(
            "generate-qr",
            ["qrencode", "-s", root.qrSize, "-o", targetPath, trimmed],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    const newSource = "file://" + targetPath + "?t=" + Date.now();
                    if (root.useImageA) {
                        root.sourceB = newSource;
                    } else {
                        root.sourceA = newSource;
                    }
                }
            },
            0
        )
    }

    function saveImage() {
        const activePath = root.useImageA ? root.pathA : root.pathB;
        if ((root.useImageA && !root.sourceA) || (!root.useImageA && !root.sourceB)) return;
        
        const cmd = "DIR=\"" + root.savePath + "\"; " +
                    "mkdir -p \"$DIR\"; " +
                    "FILENAME=\"qr_$(date +%Y-%m-%d_%H%M%S).png\"; " +
                    "cp " + activePath + " \"$DIR/$FILENAME\"";
        
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
        const activePath = root.useImageA ? root.pathA : root.pathB;
        if ((root.useImageA && !root.sourceA) || (!root.useImageA && !root.sourceB)) return;
        
        Proc.runCommand(
            "copy-qr-image",
            ["sh", "-c", "wl-copy < " + activePath + " || xclip -selection clipboard -t image/png -i " + activePath],
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
                    // Basic validation to avoid binary data (like image data)
                    // Check for null bytes or common binary headers
                    const isBinary = stdout.includes("\0") || 
                                   stdout.startsWith("\x89PNG") || 
                                   stdout.startsWith("\xff\xd8") ||
                                   stdout.startsWith("GIF8");
                    
                    if (isBinary) {
                        ToastService.showWarning("Clipboard contains binary data, not text.");
                        return;
                    }

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
            PopoutComponent {
                id: mainContent
                width: parent ? parent.width : 0
                headerText: "QR Generator"
                detailsText: ""
                showCloseButton: true
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
                            onTextEdited: root.generateQR(text)
                            onEditingFinished: root.generateQR(text)
                            onTextChanged: {
                                if (text === "") {
                                    debounceTimer.stop();
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
                        width: parent.width
                        height: width
                        color: "white"
                        radius: Theme.cornerRadius
                        border.width: 1
                        border.color: Theme.surfaceContainerHighest
                        
                        Image {
                            id: qrImageA
                            anchors.fill: parent
                            anchors.margins: 16
                            source: root.sourceA
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            opacity: root.useImageA ? 1 : 0
                            visible: opacity > 0 && !root.isFetchingWifi
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onStatusChanged: {
                                if (status === Image.Ready && !root.useImageA) {
                                    root.useImageA = true;
                                }
                            }
                        }

                        Image {
                            id: qrImageB
                            anchors.fill: parent
                            anchors.margins: 16
                            source: root.sourceB
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            opacity: !root.useImageA ? 1 : 0
                            visible: opacity > 0 && !root.isFetchingWifi
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onStatusChanged: {
                                if (status === Image.Ready && root.useImageA) {
                                    root.useImageA = false;
                                }
                            }
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

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            visible: root.sourceA === "" && root.sourceB === "" && !root.isFetchingWifi
                            opacity: 0.5

                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "qr_code_2"
                                size: 48
                                color: Theme.onSurfaceVariant
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Ready to generate"
                                color: Theme.onSurfaceVariant
                                font.pixelSize: Theme.fontSizeSmall
                            }
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
