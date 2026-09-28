import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

Rectangle {
    id: calRoot
    signal closeRequested()
    
    width: 440
    height: 480
    radius: 28
    color: "#f0161b22"
    border.color: Qt.rgba(1, 1, 1, 0.15)
    border.width: 1.5
    clip: true
    
    // Stop clicks from closing through background
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }
    
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#90000000"
        shadowBlur: 0.9
        shadowVerticalOffset: 12
    }
    
    property var displayedDate: new Date()
    property var today: new Date()
    property var monthNames: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
    property var dayNames: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.text = Qt.formatDateTime(new Date(), "HH:mm:ss")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16
        
        // Header with Clock and Date
        RowLayout {
            Layout.fillWidth: true
            
            ColumnLayout {
                spacing: 2
                
                Text {
                    id: timeText
                    text: Qt.formatDateTime(new Date(), "HH:mm:ss")
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
                
                Text {
                    text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                    font.pixelSize: 13
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Close Button
            Rectangle {
                width: 36; height: 36; radius: 18
                color: closeHover.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 16
                    color: "#ffffff"
                }
                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calRoot.closeRequested()
                }
            }
        }
        
        // Month Navigation Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.06)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                
                Text {
                    text: "◀"
                    font.pixelSize: 14
                    color: prevM.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                    MouseArea {
                        id: prevM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let d = new Date(calRoot.displayedDate);
                            d.setMonth(d.getMonth() - 1);
                            calRoot.displayedDate = d;
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: calRoot.monthNames[calRoot.displayedDate.getMonth()] + " " + calRoot.displayedDate.getFullYear()
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: "#ffffff"
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: "▶"
                    font.pixelSize: 14
                    color: nextM.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                    MouseArea {
                        id: nextM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let d = new Date(calRoot.displayedDate);
                            d.setMonth(d.getMonth() + 1);
                            calRoot.displayedDate = d;
                        }
                    }
                }
            }
        }
        
        // Days of week header
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: calRoot.dayNames
                Text {
                    text: modelData
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: index >= 5 ? "#ff7675" : Qt.rgba(1, 1, 1, 0.5)
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
        
        // Days Grid
        GridLayout {
            id: daysGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 6
            columnSpacing: 6
            
            // Helper function to build 42 calendar slots (6 weeks)
            function getDaysArray() {
                let year = calRoot.displayedDate.getFullYear();
                let month = calRoot.displayedDate.getMonth();
                let firstDay = new Date(year, month, 1);
                let lastDay = new Date(year, month + 1, 0);
                
                // Sunday = 0, convert to Monday = 0
                let startOffset = (firstDay.getDay() + 6) % 7;
                let daysInMonth = lastDay.getDate();
                
                let days = [];
                let prevMonthLastDay = new Date(year, month, 0).getDate();
                
                // Previous month padding
                for (let i = startOffset - 1; i >= 0; i--) {
                    days.push({
                        "day": prevMonthLastDay - i,
                        "isCurrent": false,
                        "isToday": false
                    });
                }
                
                // Current month
                let todayY = calRoot.today.getFullYear();
                let todayM = calRoot.today.getMonth();
                let todayD = calRoot.today.getDate();
                
                for (let i = 1; i <= daysInMonth; i++) {
                    let isTod = (year === todayY && month === todayM && i === todayD);
                    days.push({
                        "day": i,
                        "isCurrent": true,
                        "isToday": isTod
                    });
                }
                
                // Next month padding
                let nextPad = 42 - days.length;
                for (let i = 1; i <= nextPad; i++) {
                    days.push({
                        "day": i,
                        "isCurrent": false,
                        "isToday": false
                    });
                }
                return days;
            }
            
            Repeater {
                model: daysGrid.getDaysArray()
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: modelData.isToday ? "#264D60" : (modelData.isCurrent ? (dayHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)) : "transparent")
                    border.color: modelData.isToday ? "#7D8A65" : "transparent"
                    border.width: modelData.isToday ? 1.5 : 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        font.pixelSize: 13
                        font.weight: modelData.isToday ? Font.Bold : (modelData.isCurrent ? Font.DemiBold : Font.Normal)
                        color: modelData.isToday ? "#ffffff" : (modelData.isCurrent ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.25))
                    }
                    
                    MouseArea {
                        id: dayHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
        
        // Today quick button
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 12
            color: todayBtn.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
            
            Text {
                anchors.centerIn: parent
                text: "Сегодня: " + Qt.formatDateTime(new Date(), "d MMMM yyyy")
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: "#7D8A65"
            }
            
            MouseArea {
                id: todayBtn
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    calRoot.displayedDate = new Date();
                }
            }
        }
    }
}
