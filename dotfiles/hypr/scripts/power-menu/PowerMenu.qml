import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

Rectangle {
    id: powerRoot
    signal closeRequested()

    width: 580
    height: 200
    radius: 16
    color: "#f20f191e"
    border.color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1
    clip: true

    // Catch clicks so they don't dismiss the background
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            powerRoot.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_P || event.key === Qt.Key_1) {
            triggerShutdown();
            event.accepted = true;
        } else if (event.key === Qt.Key_R || event.key === Qt.Key_2) {
            triggerReboot();
            event.accepted = true;
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_3) {
            triggerLock();
            event.accepted = true;
        } else if (event.key === Qt.Key_S || event.key === Qt.Key_4) {
            triggerSuspend();
            event.accepted = true;
        } else if (event.key === Qt.Key_E || event.key === Qt.Key_5) {
            triggerLogout();
            event.accepted = true;
        }
    }

    function triggerShutdown() {
        powerRoot.closeRequested();
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function triggerReboot() {
        powerRoot.closeRequested();
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function triggerLock() {
        powerRoot.closeRequested();
        Quickshell.execDetached(["bash", "-c", "command -v hyprlock >/dev/null && hyprlock || command -v swaylock >/dev/null && swaylock || loginctl lock-session"]);
    }

    function triggerSuspend() {
        powerRoot.closeRequested();
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function triggerLogout() {
        powerRoot.closeRequested();
        Quickshell.execDetached(["bash", "-c", "niri msg action quit -s || loginctl terminate-session ${XDG_SESSION_ID:-} || pkill -i niri || pkill -i hyprland"]);
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#bb000000"
        shadowBlur: 1.0
        shadowVerticalOffset: 14
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Avatar / Profile icon
            Rectangle {
                width: 38
                height: 38
                radius: 19
                color: "#162228"
                border.color: "#65886B"
                border.width: 1.5
                clip: true

                Image {
                    anchors.fill: parent
                    source: "file:///home/chezok/.local/share/sddm/themes/konata-cat/avatar.jpg"
                    fillMode: Image.PreserveAspectCrop
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Управление питанием"
                    font.family: "JetBrainsMono Nerd Font, Adwaita Sans, sans-serif"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#dee7ea"
                }

                Text {
                    text: "chezok • CachyOS (BORE)"
                    font.family: "JetBrainsMono Nerd Font, Adwaita Sans, sans-serif"
                    font.pixelSize: 11
                    color: Qt.rgba(0.87, 0.91, 0.92, 0.5)
                }
            }

            // Close button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                border.color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: closeArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerRoot.closeRequested()
                }
            }
        }

        // Action Buttons Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // 1. Shutdown
            Rectangle {
                id: btnPower
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 12
                scale: a1.containsMouse ? 1.03 : 1.0
                color: a1.containsMouse ? Qt.rgba(0.91, 0.30, 0.24, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                border.color: a1.containsMouse ? "#e74c3c" : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰐥"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        color: a1.containsMouse ? "#ff6b6b" : "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Выключить"
                        font.family: "JetBrainsMono Nerd Font, Adwaita Sans, sans-serif"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "[P]"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: a1.containsMouse ? "#ff6b6b" : Qt.rgba(1, 1, 1, 0.35)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: a1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerRoot.triggerShutdown()
                }
            }

            // 2. Reboot
            Rectangle {
                id: btnReboot
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 12
                scale: a2.containsMouse ? 1.03 : 1.0
                color: a2.containsMouse ? Qt.rgba(0.90, 0.49, 0.13, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                border.color: a2.containsMouse ? "#e67e22" : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰜉"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        color: a2.containsMouse ? "#f39c12" : "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Рестарт"
                        font.family: "JetBrainsMono Nerd Font, Adwaita Sans, sans-serif"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "[R]"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: a2.containsMouse ? "#f39c12" : Qt.rgba(1, 1, 1, 0.35)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: a2
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerRoot.triggerReboot()
                }
            }

            // 3. Lock
            Rectangle {
                id: btnLock
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 12
                scale: a3.containsMouse ? 1.03 : 1.0
                color: a3.containsMouse ? Qt.rgba(0.33, 0.63, 0.89, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                border.color: a3.containsMouse ? "#55A0E3" : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰌾"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: a3.containsMouse ? "#55A0E3" : "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Блок"
                        font.family: "JetBrainsMono Nerd Font, Adwaita Sans, sans-serif"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "[L]"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: a3.containsMouse ? "#55A0E3" : Qt.rgba(1, 1, 1, 0.35)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: a3
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerRoot.triggerLock()
                }
            }

            // 4. Suspend
            Rectangle {
                id: btnSuspend
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 12
                scale: a4.containsMouse ? 1.03 : 1.0
                color: a4.containsMouse ? Qt.rgba(0.61, 0.35, 0.71, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                border.color: a4.containsMouse ? "#9b59b6" : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰒲"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: a4.containsMouse ? "#a29bfe" : "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Сон"
                        font.family: "JetBrainsMono Nerd Font, Adwaita Sans, sans-serif"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "[S]"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: a4.containsMouse ? "#a29bfe" : Qt.rgba(1, 1, 1, 0.35)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: a4
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerRoot.triggerSuspend()
                }
            }

            // 5. Logout
            Rectangle {
                id: btnLogout
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 12
                scale: a5.containsMouse ? 1.03 : 1.0
                color: a5.containsMouse ? Qt.rgba(0.40, 0.53, 0.42, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                border.color: a5.containsMouse ? "#65886B" : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰍃"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: a5.containsMouse ? "#65886B" : "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Выход"
                        font.family: "JetBrainsMono Nerd Font, Adwaita Sans, sans-serif"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#dee7ea"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "[E]"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: a5.containsMouse ? "#65886B" : Qt.rgba(1, 1, 1, 0.35)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: a5
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerRoot.triggerLogout()
                }
            }
        }
    }
}
