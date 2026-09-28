import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600

    Component.onCompleted: {
        Network.update();
        Network.rescanWifi();
    }

    WindowDialogTitle {
        text: "Подключение к Wi-Fi"
    }
    WindowDialogSeparator {
        visible: !Network.wifiScanning && !Network.wifiConnecting
    }
    StyledIndeterminateProgressBar {
        visible: Network.wifiScanning || Network.wifiConnecting
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }
    ListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0

        model: ScriptModel {
            values: Network.friendlyWifiNetworks
        }
        delegate: WifiNetworkItem {
            required property WifiAccessPoint modelData
            wifiNetwork: modelData
            width: ListView.view.width
        }
    }
    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Network.wifiScanning ? "Поиск..." : "Поиск"
            enabled: !Network.wifiScanning
            onClicked: {
                Network.rescanWifi();
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: "Готово"
            onClicked: root.dismiss()
        }
    }
}