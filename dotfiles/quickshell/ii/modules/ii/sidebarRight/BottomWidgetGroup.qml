pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarRight.calendar
import qs.modules.ii.sidebarRight.pomodoro
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true
    implicitHeight: 265
    property int selectedTab: 1
    property var tabs: [
        {
            "name": "Календарь",
            "icon": "calendar_month",
            "widget": "calendar/CalendarWidget.qml"
        },
        {
            "name": "Таймер",
            "icon": "schedule",
            "widget": "pomodoro/PomodoroWidget.qml"
        }
    ]

    RowLayout {
        id: bottomWidgetGroupRow
        anchors.fill: parent
        spacing: 8

        // Navigation rail with Calendar & Timer
        Item {
            Layout.fillHeight: true
            Layout.leftMargin: 8
            Layout.topMargin: 8
            implicitWidth: tabBar.implicitWidth

            NavigationRailTabArray {
                id: tabBar
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                currentIndex: root.selectedTab
                expanded: false
                Repeater {
                    model: root.tabs
                    NavigationRailButton {
                        required property int index
                        required property var modelData
                        showToggledHighlight: false
                        toggled: root.selectedTab === index
                        buttonText: modelData.name
                        buttonIcon: modelData.icon
                        onPressed: {
                            root.selectedTab = index;
                        }
                    }
                }
            }
        }

        // Content area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: tabStack
                anchors.fill: parent
                anchors.margins: 6
                source: root.tabs[root.selectedTab].widget
            }
        }
    }
}
