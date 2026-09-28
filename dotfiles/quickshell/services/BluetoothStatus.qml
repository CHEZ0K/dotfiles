pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool sysPowered: false
    readonly property bool available: Bluetooth.adapters.values.length > 0 || checkAdapterProc.hasAdapter
    readonly property bool enabled: (Bluetooth.defaultAdapter?.enabled ?? false) || sysPowered
    readonly property BluetoothDevice firstActiveDevice: Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)

    function toggleBluetooth() {
        Quickshell.execDetached(["/home/chezok/.config/hypr/scripts/bluetooth_manager.sh", "toggle"]);
        root.sysPowered = !root.enabled;
        checkPowerProc.running = true;
    }

    function connectDevice(mac) {
        if (!mac) return;
        Quickshell.execDetached(["/home/chezok/.config/hypr/scripts/bluetooth_manager.sh", "connect", mac]);
    }

    function disconnectDevice(mac) {
        if (!mac) return;
        Quickshell.execDetached(["/home/chezok/.config/hypr/scripts/bluetooth_manager.sh", "disconnect", mac]);
    }

    function pairDevice(mac) {
        if (!mac) return;
        Quickshell.execDetached(["/home/chezok/.config/hypr/scripts/bluetooth_manager.sh", "pair", mac]);
    }

    function forgetDevice(mac) {
        if (!mac) return;
        Quickshell.execDetached(["/home/chezok/.config/hypr/scripts/bluetooth_manager.sh", "forget", mac]);
    }

    Process {
        id: checkPowerProc
        command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                root.sysPowered = line.trim() === "on";
            }
        }
    }

    Process {
        id: checkAdapterProc
        property bool hasAdapter: true
        command: ["bash", "-c", "bluetoothctl list | grep -q 'Controller' && echo yes || echo no"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                checkAdapterProc.hasAdapter = line.trim() === "yes";
            }
        }
    }

    Timer {
        interval: 5000
        running: GlobalStates.sidebarRightOpen
        repeat: true
        onTriggered: {
            checkPowerProc.running = true;
        }
    }

    function sortFunction(a, b) {
        const macRegex = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;
        const aIsMac = macRegex.test(a.name);
        const bIsMac = macRegex.test(b.name);
        if (aIsMac !== bIsMac)
            return aIsMac ? 1 : -1;
        return a.name.localeCompare(b.name);
    }

    property list<var> connectedDevices: Bluetooth.devices.values.filter(d => d.connected).sort(sortFunction)
    property list<var> pairedButNotConnectedDevices: Bluetooth.devices.values.filter(d => d.paired && !d.connected).sort(sortFunction)
    property list<var> unpairedDevices: Bluetooth.devices.values.filter(d => !d.paired && !d.connected).sort(sortFunction)
    property list<var> friendlyDeviceList: [
        ...connectedDevices,
        ...pairedButNotConnectedDevices,
        ...unpairedDevices
    ]
}
