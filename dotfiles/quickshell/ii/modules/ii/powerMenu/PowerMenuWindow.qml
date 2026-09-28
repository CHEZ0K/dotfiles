import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs
import qs.services

Scope {
    id: root

    Loader {
        id: powerMenuLoader
        active: GlobalStates.sessionOpen

        sourceComponent: PanelWindow {
            id: powerWindow
            visible: powerMenuLoader.active

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: -1
            color: "transparent"

            WlrLayershell.namespace: "quickshell:powerMenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Rectangle {
                anchors.fill: parent
                color: "#70000000"

                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.sessionOpen = false;
                        event.accepted = true;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    onClicked: {
                        GlobalStates.sessionOpen = false;
                    }
                }

                PowerMenu {
                    anchors.centerIn: parent
                    onCloseRequested: {
                        GlobalStates.sessionOpen = false;
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
        }

        function open(): void {
            GlobalStates.sessionOpen = true;
        }

        function close(): void {
            GlobalStates.sessionOpen = false;
        }
    }
}
