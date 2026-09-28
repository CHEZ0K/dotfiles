import QtQuick

Item {
    id: panel
    property bool active: true
    property bool externalLanguageSwitchEnabled: false
    signal externalLanguageSwitch()

    implicitWidth: 600
    implicitHeight: 250
}
