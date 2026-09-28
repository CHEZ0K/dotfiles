import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    PanelWindow {
        id: powerWindow
        
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        exclusiveZone: -1
        color: "transparent"
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        
        Rectangle {
            anchors.fill: parent
            color: "#60000000"
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", "kill -9 " + Quickshell.processId]);
                }
            }
            
            PowerMenu {
                anchors.centerIn: parent
                onCloseRequested: {
                    Quickshell.execDetached(["bash", "-c", "kill -9 " + Quickshell.processId]);
                }
            }
        }
    }
}
