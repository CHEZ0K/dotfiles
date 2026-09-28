import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    PanelWindow {
        id: controlCenterWindow
        
        anchors {
            top: true
            bottom: true
            right: true
        }
        
        exclusiveZone: -1
        color: "transparent"
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        
        implicitWidth: 420
        
        ControlCenter {
            id: panel
            anchors.fill: parent
            onCloseRequested: {
                Quickshell.execDetached(["bash", "-c", "kill -9 " + Quickshell.processId]);
            }
        }
    }
}
