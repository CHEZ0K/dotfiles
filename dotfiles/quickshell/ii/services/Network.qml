pragma Singleton
pragma ComponentBehavior: Bound

// Took many bits from https://github.com/caelestia-dots/shell (GPLv3)

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services.network

/**
 * Network service with nmcli.
 */
Singleton {
    id: root

    property bool wifi: true
    property bool ethernet: false

    property bool wifiEnabled: false
    property bool wifiScanning: false
    property bool wifiConnecting: connectProc.running
    property string connectingSsid: ""
    property WifiAccessPoint wifiConnectTarget
    property bool wifiDisconnecting: disconnectProc.running
    property WifiAccessPoint wifiDisconnectTarget
    property var savedSsids: []
    readonly property list<WifiAccessPoint> wifiNetworks: []
    readonly property WifiAccessPoint active: wifiNetworks.find(n => n.active) ?? null
    readonly property list<var> friendlyWifiNetworks: [...wifiNetworks].sort((a, b) => {
        if (a.active && !b.active) return -1;
        if (!a.active && b.active) return 1;
        if ((a.isSaved ?? false) && !(b.isSaved ?? false)) return -1;
        if (!(a.isSaved ?? false) && (b.isSaved ?? false)) return 1;
        const tierA = Math.floor((a.strength ?? 0) / 25);
        const tierB = Math.floor((b.strength ?? 0) / 25);
        if (tierB !== tierA) return tierB - tierA;
        return (a.ssid ?? "").localeCompare(b.ssid ?? "");
    })
    property string wifiStatus: "disconnected"

    property string networkName: ""
    property int networkStrength
    property string materialSymbol: root.ethernet
        ? "lan"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? (
                (root.active?.strength ?? 0) > 83 ? "signal_wifi_4_bar" :
                (root.active?.strength ?? 0) > 67 ? "network_wifi" :
                (root.active?.strength ?? 0) > 50 ? "network_wifi_3_bar" :
                (root.active?.strength ?? 0) > 33 ? "network_wifi_2_bar" :
                (root.active?.strength ?? 0) > 17 ? "network_wifi_1_bar" :
                "signal_wifi_0_bar"
            )
            : (root.wifiStatus === "connecting")
                ? "signal_wifi_statusbar_not_connected"
                : (root.wifiStatus === "disconnected")
                    ? "wifi_find"
                    : (root.wifiStatus === "disabled")
                        ? "signal_wifi_off"
                        : "signal_wifi_bad"

    // Control
    function enableWifi(enabled = true): void {
        const cmd = enabled ? "on" : "off";
        Quickshell.execDetached(["nmcli", "radio", "wifi", cmd]);
        wifiStatusProcess.running = true;
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    function rescanWifi(): void {
        wifiScanning = true;
        rescanProcess.running = false;
        rescanProcess.running = true;
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint, password = ""): void {
        if (!accessPoint) return;
        accessPoint.askingPassword = false;
        root.connectingSsid = accessPoint.ssid;
        root.wifiConnectTarget = accessPoint;
        connectProc.command = ["/home/chezok/.config/hypr/scripts/wifi_manager.sh", "connect", accessPoint.ssid, password || ""];
        connectProc.running = false;
        connectProc.running = true;
    }

    function reconnectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        if (!accessPoint) return;
        root.connectingSsid = accessPoint.ssid;
        root.wifiConnectTarget = accessPoint;
        connectProc.command = ["/home/chezok/.config/hypr/scripts/wifi_manager.sh", "reconnect", accessPoint.ssid];
        connectProc.running = false;
        connectProc.running = true;
    }

    function disconnectWifiNetwork(accessPoint = null): void {
        const target = accessPoint || active;
        if (target) {
            root.wifiDisconnectTarget = target;
            if (target.lastIpcObject) {
                target.lastIpcObject = Object.assign({}, target.lastIpcObject, { active: false });
            }
        }
        disconnectProc.command = ["/home/chezok/.config/hypr/scripts/wifi_manager.sh", "disconnect", target ? target.ssid : ""];
        disconnectProc.running = false;
        disconnectProc.running = true;
    }

    function forgetWifiNetwork(accessPoint): void {
        if (accessPoint) {
            forgetProc.command = ["/home/chezok/.config/hypr/scripts/wifi_manager.sh", "forget", accessPoint.ssid];
            forgetProc.running = false;
            forgetProc.running = true;
        }
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"])
    }

    function changePassword(network: WifiAccessPoint, password: string, username = ""): void {
        connectToWifiNetwork(network, password);
    }

    Process {
        id: forgetProc
        stdout: SplitParser {
            onRead: {
                getNetworks.running = true;
                root.update();
            }
        }
        onExited: {
            getNetworks.running = true;
            root.update();
        }
    }

    Process {
        id: connectProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: SplitParser {
            onRead: line => {
                getNetworks.running = true;
                root.update();
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("Secrets were required") || line.includes("password") || line.includes("secret")) {
                    if (root.wifiConnectTarget && root.wifiConnectTarget.isSecure) {
                        root.wifiConnectTarget.askingPassword = true;
                    }
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.wifiConnectTarget && root.wifiConnectTarget.lastIpcObject) {
                root.wifiConnectTarget.lastIpcObject = Object.assign({}, root.wifiConnectTarget.lastIpcObject, { active: true });
            } else if (exitCode !== 0 && root.wifiConnectTarget && root.wifiConnectTarget.isSecure) {
                root.wifiConnectTarget.askingPassword = true;
            }
            root.connectingSsid = "";
            root.wifiConnectTarget = null;
            getNetworks.running = false;
            getNetworks.running = true;
            root.update();
        }
    }

    Process {
        id: disconnectProc
        stdout: SplitParser {
            onRead: {
                root.wifiDisconnectTarget = null;
                getNetworks.running = false;
                getNetworks.running = true;
                root.update();
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.wifiDisconnectTarget = null;
            getNetworks.running = false;
            getNetworks.running = true;
            root.update();
        }
    }

    Process {
        id: rescanProcess
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        stdout: SplitParser {
            onRead: {
                wifiScanning = false;
                getNetworks.running = false;
                getNetworks.running = true;
            }
        }
    }

    // Status update
    function update() {
        updateConnectionType.startCheck();
        wifiStatusProcess.running = true;
        updateNetworkName.running = true;
        updateNetworkStrength.running = true;
        updateSavedConnections.running = true;
        if (!root.wifiConnecting && !root.wifiDisconnecting) {
            getNetworks.running = false;
            getNetworks.running = true;
        }
    }

    Process {
        id: updateSavedConnections
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE c show | awk -F: '$2==\"802-11-wireless\"{print $1}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.savedSsids = text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
            }
        }
    }

    Timer {
        id: updateDebounceTimer
        interval: 400
        repeat: false
        onTriggered: root.update()
    }

    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: {
                if (!updateDebounceTimer.running) {
                    updateDebounceTimer.restart();
                }
            }
        }
    }

    Timer {
        id: periodicCheckTimer
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.update()
    }

    Process {
        id: updateConnectionType
        property string buffer
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g"]
        running: true
        function startCheck() {
            buffer = "";
            updateConnectionType.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                updateConnectionType.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const lines = updateConnectionType.buffer.trim().split('\n');
            const connectivity = lines.pop() // none, limited, full
            let hasEthernet = false;
            let hasWifi = false;
            let wifiStatus = "disconnected";
            lines.forEach(line => {
                if (line.includes("ethernet") && line.includes("connected"))
                    hasEthernet = true;
                else if (line.includes("wifi:")) {
                    if (line.includes("disconnected")) {
                        wifiStatus = "disconnected"
                    }
                    else if (line.includes("connected")) {
                        hasWifi = true;
                        wifiStatus = "connected"

                        if (connectivity === "limited") {
                            hasWifi = false;
                            wifiStatus = "limited"
                        }
                    }
                    else if (line.includes("connecting")) {
                        wifiStatus = "connecting"
                    }
                    else if (line.includes("unavailable")) {
                        wifiStatus = "disabled"
                    }
                }
            });
            root.wifiStatus = wifiStatus;
            root.ethernet = hasEthernet;
            root.wifi = hasWifi;
            if (!hasWifi && !hasEthernet) {
                root.networkName = "";
                root.networkStrength = 0;
            }
        }
    }

    Process {
        id: updateNetworkName
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME c show --active 2>/dev/null | awk -F: '$1==\"802-11-wireless\"{print $2; exit}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.networkName = text.trim();
            }
        }
    }

    Process {
        id: updateNetworkStrength
        running: true
        command: ["sh", "-c", "nmcli -f IN-USE,SIGNAL,SSID device wifi 2>/dev/null | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(text.trim());
                root.networkStrength = isNaN(val) ? 0 : val;
            }
        }
    }

    Process {
        id: wifiStatusProcess
        command: ["nmcli", "radio", "wifi"]
        Component.onCompleted: running = true
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";
            }
        }
    }

    Process {
        id: getNetworks
        running: true
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const rep = new RegExp("\\\\:", "g");
                const rep2 = new RegExp(PLACEHOLDER, "g");

                const allNetworks = text.trim().split("\n").map(n => {
                    const net = n.replace(rep, PLACEHOLDER).split(":");
                    return {
                        active: net[0] === "yes",
                        strength: parseInt(net[1]) || 0,
                        frequency: parseInt(net[2]) || 0,
                        ssid: net[3] || "",
                        bssid: net[4]?.replace(rep2, ":") ?? "",
                        security: net[5] || ""
                    };
                }).filter(n => n.ssid && n.ssid.length > 0);

                // Group networks by SSID and prioritize connected ones
                const networkMap = new Map();
                for (const network of allNetworks) {
                    const existing = networkMap.get(network.ssid);
                    if (!existing) {
                        networkMap.set(network.ssid, network);
                    } else {
                        // Prioritize active/connected networks
                        if (network.active && !existing.active) {
                            networkMap.set(network.ssid, network);
                        } else if (!network.active && !existing.active) {
                            // If both are inactive, keep the one with better signal
                            if (network.strength > existing.strength) {
                                networkMap.set(network.ssid, network);
                            }
                        }
                    }
                }

                const wifiNetworks = Array.from(networkMap.values());
                const rNetworks = root.wifiNetworks;

                // 1. Sync and prune existing AP objects
                for (let i = rNetworks.length - 1; i >= 0; i--) {
                    const rn = rNetworks[i];
                    const inScan = wifiNetworks.find(n => n.ssid === rn.ssid);
                    const isActuallyActive = root.wifiEnabled && root.networkName && rn.ssid === root.networkName;

                    if (inScan) {
                        rn.lastIpcObject = Object.assign({}, inScan, {
                            active: isActuallyActive || (inScan.active && (!root.networkName || rn.ssid === root.networkName))
                        });
                    } else {
                        // Network is out of range / absent from current scan
                        if (!root.wifiConnecting && !root.wifiDisconnecting && !(rn.isSaved ?? false)) {
                            // Unsaved absent network: remove
                            rNetworks.splice(i, 1)[0].destroy();
                        } else {
                            // Saved absent network: mark strictly inactive with zero signal
                            if (rn.lastIpcObject) {
                                rn.lastIpcObject = Object.assign({}, rn.lastIpcObject, {
                                    active: false,
                                    strength: 0
                                });
                            }
                        }
                    }
                }

                // 2. Add newly discovered networks from current scan
                for (const network of wifiNetworks) {
                    const match = rNetworks.find(n => n.ssid === network.ssid);
                    if (!match) {
                        const isActuallyActive = root.wifiEnabled && root.networkName && network.ssid === root.networkName;
                        rNetworks.push(apComp.createObject(root, {
                            lastIpcObject: Object.assign({}, network, {
                                active: isActuallyActive || (network.active && (!root.networkName || network.ssid === root.networkName))
                            })
                        }));
                    }
                }
            }
        }
    }

    Component {
        id: apComp

        WifiAccessPoint {}
    }
}
