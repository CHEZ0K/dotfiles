import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

import qs.modules.ii.sidebarRight.quickToggles.androidStyle

AbstractQuickPanel {
    id: root
    property bool editMode: false
    Layout.fillWidth: true

    // Sizes
    implicitHeight: (editMode ? contentItem.implicitHeight : panelRow.implicitHeight) + root.padding * 2
    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
    property real spacing: 4
    property real padding: 4
    readonly property real baseCellWidth: {
        const totalCols = (root.editMode ? root.columns : (root.columns + 1))
        const availableWidth = root.width - (root.padding * 2) - (root.spacing * totalCols)
        return availableWidth / totalCols
    }
    readonly property real baseCellHeight: 32

    // Toggles
    readonly property list<string> availableToggleTypes: ["network", "bluetooth", "idleInhibitor", "easyEffects", "nightLight", "darkMode", "cloudflareWarp", "gameMode", "screenSnip", "colorPicker", "onScreenKeyboard", "mic", "audio", "notifications", "powerProfile","musicRecognition", "antiFlashbang"]
    readonly property int columns: Config.options.sidebar.quickToggles.android.columns
    readonly property list<var> toggles: Config.ready ? Config.options.sidebar.quickToggles.android.toggles : []
    readonly property list<var> toggleRows: toggleRowsForList(toggles)
    readonly property list<var> unusedToggles: {
        const types = availableToggleTypes.filter(type => !toggles.some(toggle => (toggle && toggle.type === type)))
        return types.map(type => { return { type: type, size: 1 } })
    }
    readonly property list<var> unusedToggleRows: toggleRowsForList(unusedToggles)

    function toggleRowsForList(togglesList) {
        var rows = [];
        var row = [];
        var totalSize = 0; // Total cols taken in current row
        for (var i = 0; i < togglesList.length; i++) {
            if (!togglesList[i]) continue;
            if (totalSize + togglesList[i].size > columns) {
                rows.push(row);
                row = [];
                totalSize = 0;
            }
            row.push(togglesList[i]);
            totalSize += togglesList[i].size;
        }
        if (row.length > 0) {
            rows.push(row);
        }
        return rows;
    }

    Column {
        id: contentItem
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 12
        
        Row {
            id: panelRow
            spacing: root.spacing

            Column {
                id: usedRows
                spacing: root.spacing

                Repeater {
                    id: usedRowsRepeater
                    model: ScriptModel {
                        values: Array(root.toggleRows.length)
                    }
                    delegate: ButtonGroup {
                        id: toggleRow
                        required property int index
                        property var modelData: root.toggleRows[index]
                        property int startingIndex: {
                            const rows = root.toggleRows;
                            let sum = 0;
                            for (let i = 0; i < index; i++) {
                                sum += rows[i].length;
                            }
                            return sum;
                        }
                        spacing: root.spacing

                        Repeater {
                            model: ScriptModel {
                                values: toggleRow?.modelData ?? []
                                objectProp: "type"
                            }
                            delegate: AndroidToggleDelegateChooser {
                                startingIndex: toggleRow.startingIndex
                                editMode: root.editMode
                                baseCellWidth: root.baseCellWidth
                                baseCellHeight: root.baseCellHeight
                                spacing: root.spacing
                                onOpenAudioOutputDialog: root.openAudioOutputDialog()
                                onOpenAudioInputDialog: root.openAudioInputDialog()
                                onOpenBluetoothDialog: root.openBluetoothDialog()
                                onOpenNightLightDialog: root.openNightLightDialog()
                                onOpenWifiDialog: root.openWifiDialog()
                            }
                        }
                    }
                }
            }

            // Right side column: Uptime and Power button
            Column {
                id: sysControlsColumn
                spacing: root.spacing
                visible: !root.editMode

                // Row 1: Uptime Pill
                Rectangle {
                    id: uptimePill
                    width: root.baseCellWidth
                    height: root.baseCellHeight
                    radius: root.baseCellHeight / 2
                    color: Appearance.colors.colLayer2

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        CustomIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            source: SystemInfo.distroIcon
                            colorize: true
                            color: Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer2
                            text: DateTime.uptime
                        }
                    }


                }

                // Row 2: Power Button Pill
                RippleButton {
                    id: powerButton
                    width: root.baseCellWidth
                    implicitHeight: root.baseCellHeight
                    buttonRadius: root.baseCellHeight / 2
                    buttonRadiusPressed: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        GlobalStates.sessionOpen = true;
                    }

                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "power_settings_new"
                            iconSize: 16
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Питание"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    StyledToolTip {
                        text: "Управление питанием"
                    }
                }
            }
        }

        FadeLoader {
            shown: root.editMode
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: root.baseCellHeight / 2
                rightMargin: root.baseCellHeight / 2
            }
            sourceComponent: Rectangle {
                implicitHeight: 1
                color: Appearance.colors.colOutlineVariant
            }
        }

        FadeLoader {
            shown: root.editMode
            sourceComponent: Column {
                id: unusedRows
                spacing: root.spacing

                Repeater {
                    model: ScriptModel {
                        values: Array(root.unusedToggleRows.length)
                    }
                    delegate: ButtonGroup {
                        id: unusedToggleRow
                        required property int index
                        property var modelData: root.unusedToggleRows[index]
                        spacing: root.spacing

                        Repeater {
                            model: ScriptModel {
                                values: unusedToggleRow?.modelData ?? []
                                objectProp: "type"
                            }
                            delegate: AndroidToggleDelegateChooser {
                                startingIndex: -1
                                editMode: root.editMode
                                baseCellWidth: root.baseCellWidth
                                baseCellHeight: root.baseCellHeight
                                spacing: root.spacing
                            }
                        }
                    }
                }
            }
        }
    }
}
