import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.Modals.FileBrowser

PluginComponent {
    id: pluginRoot

    readonly property bool clearQrOnClose: pluginData.clearQrOnClose ?? true
    readonly property string pillStyle: pluginData.pillStyle || "icon"
    readonly property string qrSize: pluginData.qrSize || "6"
    readonly property bool showHints: pluginData.showHints ?? true
    
    property string currentText: ""
    property bool isFetchingWifi: false
    property var manualInputInput: null
    property var activePopoutReference: null
    property bool hasResult: false

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
        onTriggered: pluginRoot.generateQRInternal(pluginRoot.currentText)
    }

    function clearQR() {
        currentText = "";
        sourceA = "";
        sourceB = "";
        hasResult = false;
        if (manualInputInput) manualInputInput.text = "";
    }

    function generateQR(text) {
        if (!text || text.trim() === "") {
            currentText = "";
            sourceA = "";
            sourceB = "";
            hasResult = false;
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
        const targetPath = pluginRoot.useImageA ? pluginRoot.pathB : pluginRoot.pathA;
        
        Proc.runCommand(
            "generate-qr",
            ["qrencode", "-s", pluginRoot.qrSize, "-o", targetPath, trimmed],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    const newSource = "file://" + targetPath + "?t=" + Date.now();
                    if (pluginRoot.useImageA) {
                        pluginRoot.sourceB = newSource;
                    } else {
                        pluginRoot.sourceA = newSource;
                    }
                    pluginRoot.hasResult = true;
                }
            },
            0
        )
    }

    function saveImage() {
        if (!pluginRoot.hasResult) return;
        const activePath = pluginRoot.sourceA ? pluginRoot.pathA : pluginRoot.pathB;
        saveBrowserModal.activePath = activePath;
        saveBrowserModal.open();
    }

    FileBrowserModal {
        id: saveBrowserModal
        browserTitle: "Save QR Image"
        browserIcon: "save"
        saveMode: true
        defaultFileName: "qr_" + new Date().toISOString().replace(/[:.T]/g, '-').replace(/-/g, '').slice(0, 12) + ".png"
        fileExtensions: ["*.png"]

        property string activePath: ""

        onFileSelected: filePath => {
            let destPath = filePath;
            if (destPath.startsWith("file://")) {
                destPath = destPath.substring(7);
            } else if (destPath.startsWith("file: ")) {
                destPath = destPath.substring(6);
            }
            Proc.runCommand(
                "export-qr",
                ["sh", "-c", "cp '" + activePath + "' '" + destPath + "'"],
                (stdout, exitCode) => {
                    if (exitCode === 0) {
                        ToastService.showInfo("Saved to " + destPath);
                    } else {
                        ToastService.showError("Failed to save image.");
                    }
                },
                0
            );
            close();
        }
    }

    function copyImageToClipboard() {
        if (!pluginRoot.hasResult) return;
        const activePath = pluginRoot.sourceA ? pluginRoot.pathA : pluginRoot.pathB;
        
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
        pluginRoot.isFetchingWifi = true;
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
                pluginRoot.isFetchingWifi = false;
                const result = stdout.trim();
                if (exitCode === 0 && result !== "NO_WIFI") {
                    pluginRoot.currentText = result;
                    if (pluginRoot.manualInputInput) pluginRoot.manualInputInput.text = result;
                    pluginRoot.generateQR(result);
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
                    const isBinary = stdout.includes("\0") || 
                                   stdout.startsWith("\x89PNG") || 
                                   stdout.startsWith("\xff\xd8") ||
                                   stdout.startsWith("GIF8");
                    
                    if (isBinary) {
                        ToastService.showWarning("Clipboard contains binary data, not text.");
                        return;
                    }

                    pluginRoot.currentText = stdout;
                    pluginRoot.generateQR(stdout);
                    if (pluginRoot.manualInputInput) pluginRoot.manualInputInput.text = stdout;
                }
                
                // Only trigger (toggle) if not already visible
                if (!pluginRoot.activePopoutReference || !pluginRoot.activePopoutReference.shouldBeVisible) {
                    pluginRoot.triggerPopout();
                }
            },
            0
        )
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: horizontalRow.implicitWidth
            implicitHeight: 24
            anchors.verticalCenter: parent.verticalCenter

            property bool draggingOver: false

            Row {
                id: horizontalRow
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                scale: draggingOver ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                DankIcon {
                    name: "qr_code_2"
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (pluginRoot.hasResult ? Theme.primary : Theme.surfaceText)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "QR"
                    font.pixelSize: Theme.fontSizeSmall
                    color: pluginRoot.hasResult ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pluginRoot.pillStyle === "text"
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    if (drop.hasUrls) {
                        drop.urls.forEach(url => {
                            const text = url.toString();
                            pluginRoot.generateQR(text);
                        });
                    } else if (drop.hasText) {
                        pluginRoot.generateQR(drop.text);
                    }
                    pluginRoot.triggerPopout();
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: 24
            implicitHeight: verticalCol.implicitHeight

            property bool draggingOver: false

            Column {
                id: verticalCol
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                scale: draggingOver ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                DankIcon {
                    name: "qr_code_2"
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (pluginRoot.hasResult ? Theme.primary : Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    if (drop.hasUrls) {
                        drop.urls.forEach(url => {
                            const text = url.toString();
                            pluginRoot.generateQR(text);
                        });
                    } else if (drop.hasText) {
                        pluginRoot.generateQR(drop.text);
                    }
                    pluginRoot.triggerPopout();
                }
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
                onParentPopoutChanged: pluginRoot.activePopoutReference = parentPopout

                Connections {
                    target: parentPopout
                    function onOpened() {
                        Qt.callLater(() => {
                            if (pluginRoot.manualInputInput) pluginRoot.manualInputInput.forceActiveFocus();
                        });
                    }
                }

                Component.onDestruction: {
                    if (pluginRoot.clearQrOnClose) {
                        pluginRoot.clearQR();
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingL
                    focus: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (pluginRoot.hasResult) {
                                pluginRoot.copyImageToClipboard();
                            }
                            event.accepted = true;
                        }
                    }

                    // 1. Input & Primary Generation Section
                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankButton {
                            id: wifiButton
                            text: pluginRoot.isFetchingWifi ? "Fetching Wi-Fi..." : "Share Current Wi-Fi"
                            width: parent.width
                            iconName: pluginRoot.isFetchingWifi ? "sync" : "wifi"
                            backgroundColor: Theme.secondary
                            enabled: !pluginRoot.isFetchingWifi
                            onClicked: pluginRoot.fetchWifiAndGenerateQR()
                        }

                        DankTextField {
                            id: manualInput
                            width: parent.width
                            placeholderText: "Type or paste text here..."
                            showClearButton: true
                            focus: true
                            Component.onCompleted: {
                                pluginRoot.manualInputInput = manualInput;
                                if (pluginRoot.currentText !== "") {
                                    manualInput.text = pluginRoot.currentText;
                                }
                            }
                            onTextEdited: pluginRoot.generateQR(text)
                            onEditingFinished: pluginRoot.generateQR(text)
                            onTextChanged: {
                                if (text === "") {
                                    debounceTimer.stop();
                                    pluginRoot.currentText = "";
                                    pluginRoot.hasResult = false;
                                }
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
                            source: pluginRoot.sourceA
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            opacity: pluginRoot.useImageA ? 1 : 0
                            visible: opacity > 0 && !pluginRoot.isFetchingWifi
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onStatusChanged: {
                                if (status === Image.Ready && !pluginRoot.useImageA) {
                                    pluginRoot.useImageA = true;
                                }
                            }
                        }

                        Image {
                            id: qrImageB
                            anchors.fill: parent
                            anchors.margins: 16
                            source: pluginRoot.sourceB
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            opacity: !pluginRoot.useImageA ? 1 : 0
                            visible: opacity > 0 && !pluginRoot.isFetchingWifi
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onStatusChanged: {
                                if (status === Image.Ready && pluginRoot.useImageA) {
                                    pluginRoot.useImageA = false;
                                }
                            }
                        }

                        // Spinner during Wi-Fi fetch
                        DankIcon {
                            anchors.centerIn: parent
                            name: "sync"
                            size: 48
                            color: Theme.primary
                            visible: pluginRoot.isFetchingWifi
                            
                            RotationAnimation on rotation {
                                running: pluginRoot.isFetchingWifi
                                from: 0; to: 360; duration: 1000
                                loops: Animation.Infinite
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            visible: pluginRoot.sourceA === "" && pluginRoot.sourceB === "" && !pluginRoot.isFetchingWifi
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
                        visible: pluginRoot.hasResult

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS
                            
                            DankButton {
                                text: "Copy Image"
                                width: (parent.width - Theme.spacingS) / 2
                                iconName: "content_copy"
                                backgroundColor: Theme.primary
                                enabled: pluginRoot.hasResult
                                onClicked: pluginRoot.copyImageToClipboard()
                            }

                            DankButton {
                                text: "Save Image"
                                width: (parent.width - Theme.spacingS) / 2
                                iconName: "save"
                                backgroundColor: Theme.surfaceContainerHighest
                                textColor: Theme.surfaceText
                                enabled: pluginRoot.hasResult
                                onClicked: pluginRoot.saveImage()
                            }
                        }
                    }
                    
                    Column {
                        spacing: Theme.spacingXS
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: pluginRoot.showHints

                        Row {
                            spacing: Theme.spacingXS
                            anchors.horizontalCenter: parent.horizontalCenter
                            DankIcon { name: "lightbulb"; size: 14; color: Theme.surfaceVariantText }
                            StyledText { text: "Tip: Drop link/text onto pill icon to generate QR"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        }
                        Row {
                            spacing: Theme.spacingXS
                            anchors.horizontalCenter: parent.horizontalCenter
                            DankIcon { name: "info"; size: 14; color: Theme.surfaceVariantText }
                            StyledText { text: "Right-click bar icon to pull from clipboard. [Enter] to copy QR."; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        }
                    }
                }
            }
        }

    popoutWidth: 350
    popoutHeight: {
        let h = (pluginRoot.hasResult) ? 560 : 480;
        return pluginRoot.showHints ? h : h - 40;
    }
}
