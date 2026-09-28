import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property var device
    property bool expanded: false

    implicitWidth: ListView.view?.width ?? 360
    implicitHeight: mainColumn.implicitHeight + 16
    color: "transparent"
    radius: Appearance.rounding.normal

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 8
        }
        spacing: 6

        // Clickable header row
        RippleButton {
            id: headerButton
            Layout.fillWidth: true
            implicitHeight: 44
            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer3, root.expanded ? 0.4 : 1)
            colBackgroundHover: Appearance.colors.colLayer3Hover
            colRipple: Appearance.colors.colLayer3Active
            buttonRadius: Appearance.rounding.small
            onClicked: root.expanded = !root.expanded

            contentItem: RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 10

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.larger
                    text: Icons.getBluetoothDeviceMaterialSymbol(root.device?.icon || "")
                    color: Appearance.colors.colOnSurfaceVariant
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        color: Appearance.colors.colOnSurfaceVariant
                        elide: Text.ElideRight
                        text: root.device?.name || "Неизвестное устройство"
                        textFormat: Text.PlainText
                    }

                    StyledText {
                        visible: (root.device?.connected || root.device?.paired) ?? false
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        text: {
                            if (!root.device?.paired) return "";
                            let statusText = root.device?.connected ? "Подключено" : "Сопряжено";
                            if (!root.device?.batteryAvailable) return statusText;
                            statusText += ` • ${Math.round(root.device?.battery * 100)}%`;
                            return statusText;
                        }
                    }
                }

                MaterialSymbol {
                    text: "keyboard_arrow_down"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer3
                    rotation: root.expanded ? 180 : 0
                    Behavior on rotation {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                        }
                    }
                }
            }
        }

        // Expanded actions area
        RowLayout {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            RippleButton {
                readonly property bool p: root.device?.paired ?? false
                implicitHeight: 34
                implicitWidth: 95
                colBackground: p ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer3
                colBackgroundHover: p ? Appearance.colors.colErrorContainerHover : Appearance.colors.colLayer3Hover
                colRipple: p ? Appearance.colors.colErrorContainerActive : Appearance.colors.colLayer3Active
                buttonRadius: Appearance.rounding.small
                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: root.device?.paired ? "Забыть" : "Сопряжение"
                    color: root.device?.paired ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurface
                }
                onClicked: {
                    const mac = root.device?.address || root.device?.mac || "";
                    if (root.device?.paired) {
                        BluetoothStatus.forgetDevice(mac);
                        if (root.device?.forget) root.device.forget();
                    } else {
                        BluetoothStatus.pairDevice(mac);
                        if (root.device?.pair) root.device.pair();
                    }
                }
            }

            RippleButton {
                implicitHeight: 34
                implicitWidth: 110
                colBackground: root.device?.connected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                colBackgroundHover: root.device?.connected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colPrimaryHover
                colRipple: root.device?.connected ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colPrimaryActive
                buttonRadius: Appearance.rounding.small
                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: root.device?.connected ? "Отключить" : "Подключить"
                    color: root.device?.connected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                }
                onClicked: {
                    const mac = root.device?.address || root.device?.mac || "";
                    if (root.device?.connected) {
                        BluetoothStatus.disconnectDevice(mac);
                        if (root.device?.disconnect) root.device.disconnect();
                    } else {
                        BluetoothStatus.connectDevice(mac);
                        if (root.device?.connect) root.device.connect();
                    }
                }
            }
        }
    }
}
