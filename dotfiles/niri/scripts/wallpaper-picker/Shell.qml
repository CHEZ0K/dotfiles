//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: masterWindow
        color: "#a0000000"
        WlrLayershell.namespace: "qs-wallpaper"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        MouseArea {
            anchors.fill: parent
            onClicked: {
                picker.cancelAndClose();
            }
        }

        WallpaperPicker {
            id: picker
            anchors.fill: parent
        }
    }
}
