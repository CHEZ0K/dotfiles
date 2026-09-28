import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

WindowDialog {
    id: root
    backgroundHeight: 600

    Component.onCompleted: {
        if (!BluetoothStatus.enabled) {
            BluetoothStatus.toggleBluetooth();
        }
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = true;
        }
        Quickshell.execDetached(["bluetoothctl", "scan", "on"]);
    }
    Component.onDestruction: {
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.discovering = false;
        }
        Quickshell.execDetached(["bluetoothctl", "scan", "off"]);
    }

    WindowDialogTitle {
        text: "Устройства Bluetooth"
    }
    WindowDialogSeparator {
        visible: !(Bluetooth.defaultAdapter?.discovering ?? false)
    }
    StyledIndeterminateProgressBar {
        visible: Bluetooth.defaultAdapter?.discovering ?? false
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }
    StyledListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0
        animateAppearance: false

        model: ScriptModel {
            values: BluetoothStatus.friendlyDeviceList
        }
        delegate: BluetoothDeviceItem {
            required property BluetoothDevice modelData
            device: modelData
            anchors {
                left: parent?.left
                right: parent?.right
            }
        }
    }
    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            readonly property bool isScanning: Bluetooth.defaultAdapter?.discovering ?? false
            buttonText: isScanning ? "Поиск..." : "Поиск"
            enabled: !isScanning
            onClicked: {
                if (Bluetooth.defaultAdapter) {
                    Bluetooth.defaultAdapter.discovering = true;
                }
                Quickshell.execDetached(["bluetoothctl", "scan", "on"]);
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
