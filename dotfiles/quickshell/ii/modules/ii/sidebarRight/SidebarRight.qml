import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.sidebarRightOpen

        function hide() {
            GlobalStates.sidebarRightOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: sidebarWidth
        WlrLayershell.namespace: "quickshell:sidebarRight"
        WlrLayershell.keyboardFocus: GlobalStates.sidebarRightOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }
        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        Loader {
            id: sidebarContentLoader
            active: GlobalStates.sidebarRightOpen || Config?.options.sidebar.keepRightSidebarLoaded
            anchors {
                fill: parent
                margins: Appearance.sizes.hyprlandGapsOut
                leftMargin: Appearance.sizes.elevationMargin
            }
            width: sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

            focus: GlobalStates.sidebarRightOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panelWindow.hide();
                }
            }

            sourceComponent: SidebarRightContent {}
        }
    }

    PanelWindow {
        id: dismissArea
        visible: GlobalStates.sidebarRightOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:sidebarRightDismiss"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins {
            right: root.sidebarWidth
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onPressed: {
                GlobalStates.sidebarRightOpen = false;
            }
            onClicked: {
                GlobalStates.sidebarRightOpen = false;
            }
        }
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            if (!GlobalStates.sidebarRightOpen && sidebarContentLoader.item) {
                sidebarContentLoader.item.resetAllDialogs();
            }
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        function close(): void {
            if (sidebarContentLoader.item) {
                sidebarContentLoader.item.resetAllDialogs();
            }
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            if (sidebarContentLoader.item) {
                sidebarContentLoader.item.resetAllDialogs();
            }
            GlobalStates.sidebarRightOpen = true;
        }

        function openWifi(): void {
            if (sidebarContentLoader.item) {
                sidebarContentLoader.item.resetAllDialogs();
                sidebarContentLoader.item.showWifiDialog = true;
            }
            GlobalStates.sidebarRightOpen = true;
        }

        function openBluetooth(): void {
            if (sidebarContentLoader.item) {
                sidebarContentLoader.item.resetAllDialogs();
                sidebarContentLoader.item.showBluetoothDialog = true;
            }
            GlobalStates.sidebarRightOpen = true;
        }
    }


    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            if (!GlobalStates.sidebarRightOpen && sidebarContentLoader.item) {
                sidebarContentLoader.item.resetAllDialogs();
            }
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"

        onPressed: {
            if (sidebarContentLoader.item) {
                sidebarContentLoader.item.resetAllDialogs();
            }
            GlobalStates.sidebarRightOpen = true;
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"

        onPressed: {
            if (sidebarContentLoader.item) {
                sidebarContentLoader.item.resetAllDialogs();
            }
            GlobalStates.sidebarRightOpen = false;
        }
    }
}
