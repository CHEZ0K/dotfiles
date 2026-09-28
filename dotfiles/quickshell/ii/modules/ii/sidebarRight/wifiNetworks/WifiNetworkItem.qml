import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property WifiAccessPoint wifiNetwork
    property bool expanded: false
    readonly property bool isConnecting: {
        if (!Network.wifiConnecting) return false;
        if (Network.connectingSsid && root.wifiNetwork && Network.connectingSsid === root.wifiNetwork.ssid) return true;
        if (Network.wifiConnectTarget === root.wifiNetwork) return true;
        if (Network.wifiConnectTarget && root.wifiNetwork && Network.wifiConnectTarget.ssid === root.wifiNetwork.ssid) return true;
        return false;
    }
    readonly property bool isDisconnecting: {
        if (!Network.wifiDisconnecting) return false;
        if (Network.wifiDisconnectTarget === root.wifiNetwork) return true;
        if (Network.wifiDisconnectTarget && root.wifiNetwork && Network.wifiDisconnectTarget.ssid === root.wifiNetwork.ssid) return true;
        return false;
    }

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
                    property int strength: root.wifiNetwork?.strength ?? 0
                    text: strength > 80 ? "signal_wifi_4_bar" : strength > 60 ? "network_wifi_3_bar" : strength > 40 ? "network_wifi_2_bar" : strength > 20 ? "network_wifi_1_bar" : "signal_wifi_0_bar"
                    color: Appearance.colors.colOnSurfaceVariant
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        color: Appearance.colors.colOnSurfaceVariant
                        elide: Text.ElideRight
                        text: root.wifiNetwork?.ssid ?? "Неизвестная сеть"
                        textFormat: Text.PlainText
                    }

                    StyledText {
                        visible: root.isConnecting || root.isDisconnecting || (root.wifiNetwork?.active ?? false) || (root.wifiNetwork?.isSaved ?? false) || !(root.wifiNetwork?.isSecure ?? false)
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: (root.isConnecting || root.isDisconnecting) ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        text: root.isConnecting ? "Подключение..." : (root.isDisconnecting ? "Отключение..." : (root.wifiNetwork?.active ? "Подключено" : ((root.wifiNetwork?.isSaved ?? false) ? "Сохранено" : "Открытая сеть (без пароля)")))
                    }
                }

                MaterialSymbol {
                    visible: !root.isConnecting && !root.isDisconnecting && ((root.wifiNetwork?.isSecure || root.wifiNetwork?.active) ?? false)
                    text: root.wifiNetwork?.active ? "check" : "lock"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                    rotation: 0
                }

                MaterialSymbol {
                    visible: root.isConnecting || root.isDisconnecting
                    text: "progress_activity"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                    rotation: 0

                    RotationAnimation on rotation {
                        running: root.isConnecting || root.isDisconnecting
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
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
        ColumnLayout {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 8

            // Password field for secured unconnected networks
            MaterialTextField {
                id: passwordField
                visible: !(root.wifiNetwork?.active ?? false) && (root.wifiNetwork?.isSecure ?? false)
                enabled: !root.isConnecting && !root.isDisconnecting
                Layout.fillWidth: true
                placeholderText: (root.wifiNetwork?.isSaved ?? false) ? "Без изменений" : "Пароль сети"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData
                onAccepted: {
                    Network.connectToWifiNetwork(root.wifiNetwork, passwordField.text);
                }
            }

            StyledIndeterminateProgressBar {
                visible: root.isConnecting || root.isDisconnecting
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                RippleButton {
                    visible: (root.wifiNetwork?.active ?? false) || (root.wifiNetwork?.isSaved ?? false)
                    enabled: !root.isConnecting && !root.isDisconnecting
                    implicitHeight: 34
                    implicitWidth: 85
                    colBackground: Appearance.colors.colErrorContainer
                    colBackgroundHover: Appearance.colors.colErrorContainerHover
                    colRipple: Appearance.colors.colErrorContainerActive
                    buttonRadius: Appearance.rounding.small
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "Забыть"
                        color: Appearance.colors.colOnErrorContainer
                    }
                    onClicked: {
                        Network.forgetWifiNetwork(root.wifiNetwork);
                    }
                }

                RippleButton {
                    visible: (root.wifiNetwork?.active ?? false)
                    enabled: !root.isConnecting && !root.isDisconnecting
                    implicitHeight: 34
                    implicitWidth: 145
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    buttonRadius: Appearance.rounding.small
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: "refresh"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            text: "Переподключить"
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                    onClicked: {
                        Network.reconnectToWifiNetwork(root.wifiNetwork);
                    }
                }

                RippleButton {
                    enabled: !root.isConnecting && !root.isDisconnecting
                    implicitHeight: 34
                    implicitWidth: (root.isConnecting || root.isDisconnecting) ? 135 : 110
                    colBackground: (root.isConnecting || root.isDisconnecting)
                        ? Appearance.colors.colPrimaryContainer
                        : (root.wifiNetwork?.active ?? false)
                            ? Appearance.colors.colSecondaryContainer
                            : Appearance.colors.colPrimary
                    colBackgroundHover: (root.wifiNetwork?.active ?? false) ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colPrimaryHover
                    colRipple: (root.wifiNetwork?.active ?? false) ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colPrimaryActive
                    buttonRadius: Appearance.rounding.small
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            visible: root.isConnecting || root.isDisconnecting
                            text: "progress_activity"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                            RotationAnimation on rotation {
                                running: root.isConnecting || root.isDisconnecting
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                            }
                        }
                        StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isConnecting ? "Подключение..." : (root.isDisconnecting ? "Отключение..." : ((root.wifiNetwork?.active ?? false) ? "Отключить" : "Подключить"))
                            color: (root.isConnecting || root.isDisconnecting)
                                ? Appearance.colors.colOnPrimaryContainer
                                : ((root.wifiNetwork?.active ?? false) ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary)
                        }
                    }
                    onClicked: {
                        if (root.wifiNetwork?.active) {
                            Network.disconnectWifiNetwork(root.wifiNetwork);
                        } else {
                            Network.connectToWifiNetwork(root.wifiNetwork, passwordField ? passwordField.text : "");
                        }
                    }
                }
            }
        }
    }
}
