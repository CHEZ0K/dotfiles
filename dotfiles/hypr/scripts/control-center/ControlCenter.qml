import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root
    signal closeRequested()
    
    // Pywal color palette
    property var colors: {
        "background": "#0e1117",
        "foreground": "#e0e5cf",
        "color1": "#054960",
        "color2": "#264D60",
        "color3": "#506871",
        "color4": "#7D8A65",
        "color5": "#6F867C",
        "color6": "#A0AA8A",
        "color7": "#e0e5cf",
        "accent": "#7D8A65",
        "accent_container": "rgba(125, 138, 101, 0.25)",
        "surface": "#f0161b22",
        "surface_variant": "rgba(255, 255, 255, 0.08)",
        "on_surface": "#e0e5cf",
        "on_accent": "#ffffff"
    }
    
    // System states
    property string wifiSsid: "Подключение..."
    property bool wifiConnected: true
    property string btDevice: "Выключен"
    property bool btEnabled: false
    property real volumeVal: 0.5
    property bool isMuted: false
    property real brightnessVal: 0.7
    
    // Media states
    property string mediaTitle: "Нет трека"
    property string mediaArtist: "Исполнитель не найден"
    property string mediaStatus: "Stopped"
    property string mediaArt: ""
    property real mediaPosition: 0.0
    property real mediaDuration: 1.0
    
    // Visualizer wave animation
    property real wavePhase: 0.0
    NumberAnimation on wavePhase {
        from: 0.0; to: Math.PI * 2
        duration: 2000
        loops: Animation.Infinite
        running: root.mediaStatus === "Playing"
    }

    Component.onCompleted: {
        updateSystemState();
        stateTimer.start();
    }
    
    Timer {
        id: stateTimer
        interval: 1000
        repeat: true
        onTriggered: root.updateSystemState()
    }
    
    function updateSystemState() {
        Quickshell.execDetached(["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ > /tmp/cc_vol.tmp; brightnessctl -e4 -n2 g > /tmp/cc_bright.tmp; nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' > /tmp/cc_wifi.tmp; bluetoothctl show | grep 'Powered:' > /tmp/cc_bt.tmp; playerctl metadata --format '{{title}}:::{{artist}}:::{{status}}:::{{mpris:artUrl}}:::{{position}}:::{{mpris:length}}' 2>/dev/null > /tmp/cc_media.tmp"]);
        readTimer.restart();
    }
    
    Timer {
        id: readTimer
        interval: 100
        onTriggered: readStateFiles()
    }
    
    function readStateFiles() {
        // Read volume
        try {
            let volProc = Process.exec(["cat", "/tmp/cc_vol.tmp"]);
            if (volProc && volProc.stdout) {
                let txt = volProc.stdout.trim();
                let m = txt.match(/Volume:\s+([0-9.]+)/);
                if (m) root.volumeVal = Math.min(1.0, parseFloat(m[1]));
                root.isMuted = txt.includes("[MUTED]");
            }
        } catch(e) {}
        
        // Read brightness
        try {
            let bProc = Process.exec(["bash", "-c", "echo $(($(brightnessctl -e4 -n2 g) * 100 / $(brightnessctl -e4 -n2 m)))"]);
            if (bProc && bProc.stdout) {
                let v = parseInt(bProc.stdout.trim());
                if (!isNaN(v)) root.brightnessVal = Math.max(0.05, Math.min(1.0, v / 100.0));
            }
        } catch(e) {}
        
        // Read Wi-Fi
        try {
            let wProc = Process.exec(["cat", "/tmp/cc_wifi.tmp"]);
            if (wProc && wProc.stdout && wProc.stdout.trim() !== "") {
                let line = wProc.stdout.trim().split(":");
                root.wifiSsid = line.length > 1 ? line[1] : "Wi-Fi";
                root.wifiConnected = true;
            } else {
                root.wifiSsid = "Отключен";
                root.wifiConnected = false;
            }
        } catch(e) {}
        
        // Read Bluetooth
        try {
            let btProc = Process.exec(["cat", "/tmp/cc_bt.tmp"]);
            if (btProc && btProc.stdout && btProc.stdout.includes("yes")) {
                root.btEnabled = true;
                let btDevProc = Process.exec(["bash", "-c", "bluetoothctl devices Connected | head -n 1 | cut -d' ' -f3-"]);
                if (btDevProc && btDevProc.stdout && btDevProc.stdout.trim() !== "") {
                    root.btDevice = btDevProc.stdout.trim();
                } else {
                    root.btDevice = "Включен";
                }
            } else {
                root.btEnabled = false;
                root.btDevice = "Выключен";
            }
        } catch(e) {}
        
        // Read Media
        try {
            let mProc = Process.exec(["cat", "/tmp/cc_media.tmp"]);
            if (mProc && mProc.stdout && mProc.stdout.trim() !== "") {
                let p = mProc.stdout.trim().split(":::");
                if (p.length >= 4) {
                    root.mediaTitle = p[0] || "Без названия";
                    root.mediaArtist = p[1] || "Неизвестен";
                    root.mediaStatus = p[2] || "Stopped";
                    root.mediaArt = p[3] || "";
                    let pos = parseFloat(p[4] || "0") / 1000000.0;
                    let len = parseFloat(p[5] || "1") / 1000000.0;
                    root.mediaPosition = pos;
                    root.mediaDuration = Math.max(1.0, len);
                }
            } else {
                root.mediaStatus = "Stopped";
                root.mediaTitle = "Нет музыки";
                root.mediaArtist = "Плеер не активен";
                root.mediaArt = "";
            }
        } catch(e) {}
    }

    // Keyboard & backdrop click
    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()
    }
    
    // Backdrop & main container
    Rectangle {
        id: bgContainer
        anchors.fill: parent
        anchors.margins: 10
        radius: 28
        color: root.colors.surface
        border.color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1.5
        clip: true
        
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.8
            shadowVerticalOffset: 8
        }
        
        Flickable {
            id: scrollArea
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: width
            contentHeight: mainCol.implicitHeight + 20
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            
            ColumnLayout {
                id: mainCol
                width: scrollArea.width
                spacing: 16
                
                // ===== HEADER =====
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Панель управления Pixel"
                        color: root.colors.on_surface
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }
                    
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : root.colors.surface_variant
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: root.colors.on_surface
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }
                
                // ===== 1. GOOGLE PIXEL TOP TILES (2 WIDE PILLS) =====
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    // WI-FI TILE
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: 20
                        color: root.wifiConnected ? root.colors.color4 : root.colors.surface_variant
                        border.color: root.wifiConnected ? Qt.lighter(root.colors.color4, 1.2) : Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: root.wifiConnected ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.1)
                                Image {
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    source: "./assets/icons/fluent/wifi-4.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "Интернет"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                                Text {
                                    text: root.wifiSsid
                                    font.pixelSize: 11
                                    color: Qt.rgba(1, 1, 1, 0.8)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "nmcli radio wifi " + (root.wifiConnected ? "off" : "on")]);
                                stateTimer.restart();
                            }
                        }
                    }
                    
                    // BLUETOOTH TILE
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: 20
                        color: root.btEnabled ? root.colors.color2 : root.colors.surface_variant
                        border.color: root.btEnabled ? Qt.lighter(root.colors.color2, 1.2) : Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: root.btEnabled ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.1)
                                Image {
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    source: "./assets/icons/fluent/bluetooth-connected.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "Bluetooth"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                                Text {
                                    text: root.btDevice
                                    font.pixelSize: 11
                                    color: Qt.rgba(1, 1, 1, 0.8)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c", "bluetoothctl power " + (root.btEnabled ? "off" : "on")]);
                                stateTimer.restart();
                            }
                        }
                    }
                }
                
                // ===== 2. MATERIAL YOU THICK SLIDERS =====
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    // VOLUME SLIDER
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 24
                        color: root.colors.surface_variant
                        clip: true
                        
                        Rectangle {
                            width: parent.width * (root.isMuted ? 0 : root.volumeVal)
                            height: parent.height
                            radius: 24
                            color: root.isMuted ? Qt.rgba(1, 1, 1, 0.2) : root.colors.color5
                            Behavior on width { NumberAnimation { duration: 100 } }
                        }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            
                            Image {
                                width: 20; height: 20
                                source: root.isMuted ? "./assets/icons/fluent/speaker-mute-filled.svg" : "./assets/icons/fluent/speaker-2-filled.svg"
                                fillMode: Image.PreserveAspectFit
                            }
                            
                            Text {
                                text: "Громкость"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: root.isMuted ? "Без звука" : Math.round(root.volumeVal * 100) + "%"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    let v = Math.max(0, Math.min(1.0, mouse.x / width));
                                    root.volumeVal = v;
                                    Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]);
                                }
                            }
                            onClicked: (mouse) => {
                                let v = Math.max(0, Math.min(1.0, mouse.x / width));
                                root.volumeVal = v;
                                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]);
                            }
                        }
                    }
                    
                    // BRIGHTNESS SLIDER
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 24
                        color: root.colors.surface_variant
                        clip: true
                        
                        Rectangle {
                            width: parent.width * root.brightnessVal
                            height: parent.height
                            radius: 24
                            color: root.colors.color6
                            Behavior on width { NumberAnimation { duration: 100 } }
                        }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            
                            Image {
                                width: 20; height: 20
                                source: "./assets/icons/fluent/weather-sunny-filled.svg"
                                fillMode: Image.PreserveAspectFit
                            }
                            
                            Text {
                                text: "Яркость"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: Math.round(root.brightnessVal * 100) + "%"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    let v = Math.max(0.05, Math.min(1.0, mouse.x / width));
                                    root.brightnessVal = v;
                                    Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "s", Math.round(v * 100) + "%"]);
                                }
                            }
                            onClicked: (mouse) => {
                                let v = Math.max(0.05, Math.min(1.0, mouse.x / width));
                                root.brightnessVal = v;
                                Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "s", Math.round(v * 100) + "%"]);
                            }
                        }
                    }
                }
                
                // ===== 3. RICH MEDIA PLAYER CARD (BLURRED ARTWORK & CIRCULAR VISUALIZER) =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: 24
                    color: root.colors.surface_variant
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    clip: true
                    
                    Image {
                        id: bgArt
                        anchors.fill: parent
                        source: root.mediaArt !== "" ? root.mediaArt : ""
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.25
                        visible: root.mediaArt !== ""
                        layer.enabled: true
                        layer.effect: MultiEffect { blur: 0.9; blurMax: 32 }
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Item {
                                width: 64; height: 64
                                
                                Canvas {
                                    id: visCanvas
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onPaint: {
                                        let ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        if (root.mediaStatus !== "Playing") return;
                                        
                                        let cx = width / 2;
                                        let cy = height / 2;
                                        let baseR = 34;
                                        ctx.beginPath();
                                        for (let a = 0; a <= Math.PI * 2; a += 0.1) {
                                            let wave = Math.sin(a * 6 + root.wavePhase) * 3;
                                            let r = baseR + wave;
                                            let x = cx + Math.cos(a) * r;
                                            let y = cy + Math.sin(a) * r;
                                            if (a === 0) ctx.moveTo(x, y);
                                            else ctx.lineTo(x, y);
                                        }
                                        ctx.closePath();
                                        ctx.strokeStyle = root.colors.color6;
                                        ctx.lineWidth = 2.0;
                                        ctx.stroke();
                                    }
                                    Connections {
                                        target: root
                                        function onWavePhaseChanged() { visCanvas.requestPaint(); }
                                    }
                                }
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 16
                                    color: root.colors.surface
                                    clip: true
                                    border.color: Qt.rgba(1, 1, 1, 0.2)
                                    border.width: 1
                                    
                                    Image {
                                        anchors.fill: parent
                                        source: root.mediaArt !== "" ? root.mediaArt : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: root.mediaArt !== ""
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🎵"
                                        font.pixelSize: 24
                                        visible: root.mediaArt === ""
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                
                                Text {
                                    text: root.mediaTitle
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                
                                Text {
                                    text: root.mediaArtist
                                    font.pixelSize: 12
                                    color: Qt.rgba(1, 1, 1, 0.7)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.15)
                            
                            Rectangle {
                                width: parent.width * Math.min(1.0, root.mediaPosition / root.mediaDuration)
                                height: parent.height
                                radius: 3
                                color: root.colors.color4
                            }
                        }
                        
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 24
                            
                            Image {
                                width: 22; height: 22
                                source: "./assets/icons/fluent/previous-filled.svg"
                                fillMode: Image.PreserveAspectFit
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["playerctl", "previous"]);
                                        stateTimer.restart();
                                    }
                                }
                            }
                            
                            Rectangle {
                                width: 38; height: 38; radius: 19
                                color: playMouse.containsMouse ? Qt.lighter(root.colors.color4, 1.2) : root.colors.color4
                                
                                Image {
                                    anchors.centerIn: parent
                                    width: 18; height: 18
                                    source: root.mediaStatus === "Playing" ? "./assets/icons/fluent/pause-filled.svg" : "./assets/icons/fluent/play-filled.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                                
                                MouseArea {
                                    id: playMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["playerctl", "play-pause"]);
                                        stateTimer.restart();
                                    }
                                }
                            }
                            
                            Image {
                                width: 22; height: 22
                                source: "./assets/icons/fluent/next-filled.svg"
                                fillMode: Image.PreserveAspectFit
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["playerctl", "next"]);
                                        stateTimer.restart();
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ===== 4. NOTIFICATIONS SECTION =====
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Уведомления"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: root.colors.on_surface
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "Очистить"
                            font.pixelSize: 12
                            color: notifClrMouse.containsMouse ? "#ffffff" : root.colors.color6
                            MouseArea {
                                id: notifClrMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["bash", "-c", "command -v makoctl >/dev/null && makoctl dismiss -a || command -v dunstctl >/dev/null && dunstctl close-all || true"])
                            }
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        radius: 18
                        color: root.colors.surface_variant
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            
                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: Qt.rgba(1, 1, 1, 0.1)
                                Image {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: "./assets/icons/fluent/alert-filled.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "Система оптимизирована"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: "#ffffff"
                                }
                                Text {
                                    text: "Waybar, Quickshell и CachyOS активны"
                                    font.pixelSize: 11
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                }
                            }
                        }
                    }
                }
                
                // ===== 5. BOTTOM CALENDAR =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 180
                    radius: 24
                    color: root.colors.accent_container
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Календарь"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: "#ffffff"
                                Layout.fillWidth: true
                            }
                            Text {
                                text: Qt.formatDateTime(new Date(), "dd MMMM yyyy")
                                font.pixelSize: 12
                                color: Qt.rgba(1, 1, 1, 0.8)
                            }
                        }
                        
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7
                            rowSpacing: 4
                            columnSpacing: 4
                            
                            Repeater {
                                model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                                Text {
                                    text: modelData
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                }
                            }
                            
                            Repeater {
                                model: 28
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    radius: 6
                                    property int dayNum: index + 1
                                    property bool isToday: dayNum === new Date().getDate()
                                    color: isToday ? root.colors.color4 : "transparent"
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: dayNum
                                        font.pixelSize: 11
                                        font.weight: parent.isToday ? Font.Bold : Font.Normal
                                        color: parent.isToday ? "#ffffff" : Qt.rgba(1, 1, 1, 0.8)
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
