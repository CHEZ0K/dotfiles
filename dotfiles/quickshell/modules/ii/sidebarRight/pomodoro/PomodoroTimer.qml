import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    readonly property var presets: [
        {"label": "1м", "seconds": 60},
        {"label": "5м", "seconds": 300},
        {"label": "10м", "seconds": 600},
        {"label": "15м", "seconds": 900},
        {"label": "25м", "seconds": 1500},
        {"label": "30м", "seconds": 1800}
    ]

    function commitInputs() {
        let h = parseInt(hoursInput.text) || 0;
        let m = parseInt(minutesInput.text) || 0;
        let s = parseInt(secondsInput.text) || 0;
        let total = h * 3600 + m * 60 + s;
        if (total > 0) {
            TimerService.setDuration(total);
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 10

        // ==================== OVAL TIMER CAPSULE ====================
        Rectangle {
            id: timerCapsule
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 260
            implicitHeight: 74
            radius: height / 2
            color: Appearance.colors.colLayer2
            border.color: TimerService.timerFinished ? Appearance.colors.colError : (TimerService.timerRunning ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant)
            border.width: (TimerService.timerRunning || TimerService.timerFinished) ? 2 : 1
            clip: true

            // Progress Fill inside the oval
            Rectangle {
                id: progressFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: parent.radius
                width: {
                    if (TimerService.customDuration <= 0) return 0;
                    let progress = TimerService.timeLeftMs / (TimerService.customDuration * 1000);
                    return parent.width * Math.max(0, Math.min(1, progress));
                }
                color: TimerService.timerFinished ? Appearance.colors.colErrorContainer : Appearance.colors.colPrimaryContainer
                opacity: 0.35
                visible: TimerService.timerRunning || TimerService.timerFinished
            }

            // --- VIEW 1: RUNNING / FINISHED COUNTDOWN WITH MILLISECONDS ---
            Item {
                anchors.fill: parent
                visible: TimerService.timerRunning || TimerService.timerFinished

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        StyledText {
                            text: {
                                let totalMs = Math.max(0, TimerService.timeLeftMs);
                                let h = Math.floor(totalMs / 3600000);
                                let m = Math.floor((totalMs % 3600000) / 60000).toString().padStart(2, '0');
                                let s = Math.floor((totalMs % 60000) / 1000).toString().padStart(2, '0');
                                return h > 0 ? `${h.toString().padStart(2, '0')}:${m}:${s}` : `${m}:${s}`;
                            }
                            font.pixelSize: 32
                            font.weight: Font.DemiBold
                            color: Appearance.m3colors.m3onSurface
                        }

                        StyledText {
                            text: "." + Math.floor((Math.max(0, TimerService.timeLeftMs) % 1000) / 10).toString().padStart(2, '0')
                            font.pixelSize: 20
                            font.weight: Font.Medium
                            color: TimerService.timerFinished ? Appearance.colors.colError : Appearance.colors.colPrimary
                            Layout.alignment: Qt.AlignBaseline
                        }
                    }

                    StyledText {
                        visible: TimerService.timerFinished
                        Layout.alignment: Qt.AlignHCenter
                        text: "Время вышло!"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: Appearance.colors.colError
                    }
                }
            }

            // --- VIEW 2: STOPPED / EDITABLE (3 SEPARATE FIELDS: Ч, М, С) ---
            Item {
                anchors.fill: parent
                visible: !TimerService.timerRunning && !TimerService.timerFinished

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    // HOURS
                    ColumnLayout {
                        spacing: 1
                        Layout.alignment: Qt.AlignHCenter

                        TextInput {
                            id: hoursInput
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 44
                            selectByMouse: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                            font.family: Appearance.font.family.main
                            color: activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3onSurface
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: RegularExpressionValidator { regularExpression: /^[0-9]{1,2}$/ }

                            onActiveFocusChanged: {
                                if (activeFocus) selectAll();
                                else root.commitInputs();
                            }
                            onAccepted: {
                                root.commitInputs();
                                focus = false;
                            }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Space || event.key === Qt.Key_R || event.key === Qt.Key_S) event.accepted = true;
                                else if (event.key === Qt.Key_Escape) { focus = false; event.accepted = true; }
                                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { minutesInput.forceActiveFocus(); event.accepted = true; }
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Ч"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Appearance.colors.colSubtext
                        }
                    }

                    // SEPARATOR :
                    StyledText {
                        text: ":"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: Appearance.colors.colSubtext
                        Layout.alignment: Qt.AlignVCenter
                        Layout.bottomMargin: 10
                    }

                    // MINUTES
                    ColumnLayout {
                        spacing: 1
                        Layout.alignment: Qt.AlignHCenter

                        TextInput {
                            id: minutesInput
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 44
                            selectByMouse: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                            font.family: Appearance.font.family.main
                            color: activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3onSurface
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: RegularExpressionValidator { regularExpression: /^[0-9]{1,2}$/ }

                            onActiveFocusChanged: {
                                if (activeFocus) selectAll();
                                else root.commitInputs();
                            }
                            onAccepted: {
                                root.commitInputs();
                                focus = false;
                            }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Space || event.key === Qt.Key_R || event.key === Qt.Key_S) event.accepted = true;
                                else if (event.key === Qt.Key_Escape) { focus = false; event.accepted = true; }
                                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { secondsInput.forceActiveFocus(); event.accepted = true; }
                                else if (event.key === Qt.Key_Left) { hoursInput.forceActiveFocus(); event.accepted = true; }
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "М"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Appearance.colors.colSubtext
                        }
                    }

                    // SEPARATOR :
                    StyledText {
                        text: ":"
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: Appearance.colors.colSubtext
                        Layout.alignment: Qt.AlignVCenter
                        Layout.bottomMargin: 10
                    }

                    // SECONDS
                    ColumnLayout {
                        spacing: 1
                        Layout.alignment: Qt.AlignHCenter

                        TextInput {
                            id: secondsInput
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 44
                            selectByMouse: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                            font.family: Appearance.font.family.main
                            color: activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3onSurface
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: RegularExpressionValidator { regularExpression: /^[0-9]{1,2}$/ }

                            onActiveFocusChanged: {
                                if (activeFocus) selectAll();
                                else root.commitInputs();
                            }
                            onAccepted: {
                                root.commitInputs();
                                focus = false;
                            }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Space || event.key === Qt.Key_R || event.key === Qt.Key_S) event.accepted = true;
                                else if (event.key === Qt.Key_Escape) { focus = false; event.accepted = true; }
                                else if (event.key === Qt.Key_Left) { minutesInput.forceActiveFocus(); event.accepted = true; }
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "С"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // Bindings to sync from TimerService when not focused
                Binding {
                    target: hoursInput
                    property: "text"
                    value: Math.floor(TimerService.secondsLeft / 3600).toString().padStart(2, '0')
                    when: !hoursInput.activeFocus
                }

                Binding {
                    target: minutesInput
                    property: "text"
                    value: Math.floor((TimerService.secondsLeft % 3600) / 60).toString().padStart(2, '0')
                    when: !minutesInput.activeFocus
                }

                Binding {
                    target: secondsInput
                    property: "text"
                    value: Math.floor(TimerService.secondsLeft % 60).toString().padStart(2, '0')
                    when: !secondsInput.activeFocus
                }
            }
        }

        // Quick Preset Buttons & Adjustments
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            // -1 minute
            RippleButton {
                implicitHeight: 26
                implicitWidth: 30
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: TimerService.addSeconds(-60)

                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "-1м"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                }
            }

            // Presets
            Repeater {
                model: root.presets
                delegate: RippleButton {
                    required property var modelData
                    readonly property bool isCurrent: TimerService.customDuration === modelData.seconds

                    implicitHeight: 26
                    implicitWidth: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: isCurrent ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                    colBackgroundHover: isCurrent ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover

                    onClicked: TimerService.setDuration(modelData.seconds)

                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: isCurrent ? Font.DemiBold : Font.Normal
                        color: isCurrent ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                    }
                }
            }

            // +1 minute
            RippleButton {
                implicitHeight: 26
                implicitWidth: 30
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: TimerService.addSeconds(60)

                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "+1м"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        // The Start/Stop and Reset buttons
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            RippleButton {
                implicitHeight: 34
                implicitWidth: 100
                font.pixelSize: Appearance.font.pixelSize.large
                onClicked: TimerService.toggleTimer()
                colBackground: TimerService.timerRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.timerRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimaryHover

                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: TimerService.timerRunning ? "Пауза" : ((TimerService.secondsLeft === TimerService.customDuration && !TimerService.timerFinished) ? "Старт" : "Продолжить")
                    color: TimerService.timerRunning ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                }
            }

            RippleButton {
                implicitHeight: 34
                implicitWidth: 90
                font.pixelSize: Appearance.font.pixelSize.large
                onClicked: TimerService.resetTimer()
                enabled: (TimerService.secondsLeft < TimerService.customDuration) || TimerService.timerFinished

                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive

                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "Сброс"
                    color: Appearance.colors.colOnErrorContainer
                }
            }
        }
    }
}
