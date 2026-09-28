import QtQuick
import qs.services

QtObject {
    required property var lastIpcObject
    readonly property string ssid: lastIpcObject?.ssid ?? ""
    readonly property string bssid: lastIpcObject?.bssid ?? ""
    readonly property int strength: lastIpcObject?.strength ?? 0
    readonly property int frequency: lastIpcObject?.frequency ?? 0
    readonly property bool active: {
        if (!Network.wifiEnabled || Network.wifiStatus === "disconnected" || Network.wifiStatus === "disabled") {
            return false;
        }
        if (Network.networkName && Network.networkName.length > 0) {
            return ssid === Network.networkName;
        }
        return lastIpcObject?.active ?? false;
    }
    readonly property string security: lastIpcObject?.security ?? ""
    readonly property bool isSecure: security.length > 0 && security !== "--"
    readonly property bool isSaved: (Network.savedSsids ?? []).includes(ssid)

    property bool askingPassword: false
}
