import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#000000"

    // UI State
    property bool uiActive: false
    property real blurAmount: uiActive ? 0.85 : 0.0
    property bool showPowerMenu: false
    property bool showVirtualKeyboard: false
    property string currentLayoutName: "US"
    property int currentSessionIndex: 0
    property string currentSessionName: "niri"
    property bool isShiftActive: false
    property string currentKeyboardLang: "EN" // "EN" or "RU"

    // Reset activity timer
    function resetActivity() {
        uiActive = true
        idleTimer.restart()
    }

    // Login action
    function doLogin() {
        resetActivity()
        var username = (typeof userModel !== "undefined" && userModel && userModel.lastUser) ? userModel.lastUser : "chezok"
        var pwd = passwordInput.text
        if (typeof sddm !== "undefined" && sddm) {
            sddm.login(username, pwd, currentSessionIndex)
        } else {
            console.log("Mock login: user=" + username + " session=" + currentSessionName)
            if (pwd === "") {
                errorMessage.text = "Введите пароль"
            } else {
                errorMessage.color = "#80ff80"
                errorMessage.text = "Успешный вход (" + username + ")"
            }
        }
    }

    function appendPasswordChar(ch) {
        passwordInput.text += ch
        passwordInput.cursorPosition = passwordInput.text.length
        passwordInput.forceActiveFocus()
        resetActivity()
    }

    function backspacePassword() {
        if (passwordInput.text.length > 0) {
            passwordInput.text = passwordInput.text.slice(0, -1)
            passwordInput.cursorPosition = passwordInput.text.length
        }
        passwordInput.forceActiveFocus()
        resetActivity()
    }

    // Toggle layout
    function toggleLayout() {
        resetActivity()
        if (typeof keyboard !== "undefined" && keyboard && keyboard.layouts && keyboard.layouts.length > 0) {
            keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            updateLayoutLabel()
        } else {
            currentLayoutName = (currentLayoutName === "US") ? "RU" : "US"
            currentKeyboardLang = currentLayoutName
        }
    }

    function updateLayoutLabel() {
        if (typeof keyboard !== "undefined" && keyboard && keyboard.layouts && keyboard.layouts.length > 0) {
            var layout = keyboard.layouts[keyboard.currentLayout]
            currentLayoutName = layout ? (layout.shortName ? layout.shortName.toUpperCase() : "US") : "US"
            currentKeyboardLang = currentLayoutName === "RU" ? "RU" : "EN"
        }
    }

    // Cycle sessions
    function cycleSession() {
        resetActivity()
        if (typeof sessionModel !== "undefined" && sessionModel && sessionModel.rowCount() > 0) {
            currentSessionIndex = (currentSessionIndex + 1) % sessionModel.rowCount()
            updateSessionLabel()
        } else {
            currentSessionName = (currentSessionName === "niri") ? "weston" : "niri"
        }
    }

    function updateSessionLabel() {
        if (typeof sessionModel !== "undefined" && sessionModel && sessionModel.rowCount() > 0) {
            var name = sessionModel.data(sessionModel.index(currentSessionIndex, 0), Qt.UserRole + 4)
            if (!name) {
                name = sessionModel.data(sessionModel.index(currentSessionIndex, 0), Qt.DisplayRole)
            }
            currentSessionName = name ? name : "niri"
        }
    }

    // Background Video Player
    MediaPlayer {
        id: videoPlayer
        source: Qt.resolvedUrl("video.mp4")
        videoOutput: videoOutput
        audioOutput: AudioOutput { muted: true }
        loops: MediaPlayer.Infinite
        Component.onCompleted: videoPlayer.play()
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: false // Fed into MultiEffect
    }

    // Smooth blur effect on video
    MultiEffect {
        id: videoBlurEffect
        anchors.fill: videoOutput
        source: videoOutput
        blurEnabled: true
        blur: root.blurAmount
        blurMax: 32
        brightness: -root.blurAmount * 0.12
        saturation: 1.0 - (root.blurAmount * 0.15)
        Behavior on blur {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
        Behavior on brightness {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
        Behavior on saturation {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
    }

    // Dark vignette overlay when blurred
    Rectangle {
        anchors.fill: parent
        color: "#30000510"
        opacity: root.uiActive ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
    }

    // Global Key and Mouse catcher
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (!root.uiActive) {
                root.resetActivity()
                passwordInput.forceActiveFocus()
                event.accepted = true
                return
            }

            root.resetActivity()

            if (event.key === Qt.Key_Escape) {
                if (root.showVirtualKeyboard) {
                    root.showVirtualKeyboard = false
                } else if (root.showPowerMenu) {
                    root.showPowerMenu = false
                } else {
                    root.uiActive = false
                }
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            onPressed: {
                if (!root.uiActive) {
                    root.resetActivity()
                    passwordInput.forceActiveFocus()
                } else {
                    root.resetActivity()
                    root.showPowerMenu = false
                }
            }
        }
    }

    // Idle Timer (30 seconds)
    Timer {
        id: idleTimer
        interval: 30000
        running: root.uiActive
        repeat: false
        onTriggered: {
            root.uiActive = false
            root.showPowerMenu = false
            root.showVirtualKeyboard = false
        }
    }

    // Hint banner shown when idle
    Item {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: !root.uiActive ? 0.85 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.centerIn: parent
            width: hintRow.implicitWidth + 36
            height: 42
            radius: 21
            color: "#60000000"
            border.color: "#30ffffff"
            border.width: 1

            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: "⌨ Нажмите любую клавишу или кликните мышью"
                    color: "#f0ffffff"
                    font.pixelSize: 14
                    font.family: "Sans Serif"
                }
            }
        }
    }

    // ============================================================
    // MAIN UI CONTAINER (Right side, slightly below horizontal center)
    // ============================================================
    Item {
        id: mainUiContainer
        anchors.right: parent.right
        anchors.rightMargin: Math.max(70, parent.width * 0.09)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 60 // чуть ниже центра горизонтали

        width: contentColumn.implicitWidth
        height: contentColumn.implicitHeight

        opacity: root.uiActive ? 1.0 : 0.0
        scale: root.uiActive ? 1.0 : 0.88
        transformOrigin: Item.Right

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
        }
        Behavior on scale {
            NumberAnimation { duration: 350; easing.type: Easing.OutBack }
        }

        Column {
            id: contentColumn
            spacing: 20

            // Row with Avatar + (Username & Password Input)
            Row {
                spacing: 24

                // 1. Avatar (Rounded Parallelogram)
                Item {
                    id: avatarWrapper
                    width: 88
                    height: 88

                    // Mask: rounded rectangle sheared horizontally
                    Rectangle {
                        id: avatarMask
                        width: 88
                        height: 88
                        radius: 14
                        color: "white"
                        visible: false
                        layer.enabled: true
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(
                                1, -0.22, 0, 0,
                                0,  1,    0, 0,
                                0,  0,    1, 0,
                                0,  0,    0, 1
                            )
                        }
                    }

                    Image {
                        id: rawAvatar
                        source: Qt.resolvedUrl("avatar.jpg")
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        layer.enabled: true
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: rawAvatar
                        maskSource: avatarMask
                    }

                    // Parallelogram border with smooth glowing edge
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: "transparent"
                        border.color: "#70ffffff"
                        border.width: 1.8
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(
                                1, -0.22, 0, 0,
                                0,  1,    0, 0,
                                0,  0,    1, 0,
                                0,  0,    0, 1
                            )
                        }
                    }
                }

                // 2. Column: Username + Password Field
                Column {
                    spacing: 8

                    // Username text above password field
                    Row {
                        spacing: 8

                        Rectangle {
                            width: 8; height: 8
                            radius: 4
                            color: "#50fa7b"
                        }

                        Text {
                            text: (typeof userModel !== "undefined" && userModel && userModel.lastUser) ? userModel.lastUser : "chezok"
                            color: "#ffffff"
                            font.pixelSize: 21
                            font.bold: true
                            font.family: "Sans Serif"
                            style: Text.Outline
                            styleColor: "#60000000"
                        }
                    }

                    // Password Field (Rounded Parallelogram)
                    Item {
                        id: passwordBox
                        width: 290
                        height: 48

                        Rectangle {
                            id: passwordBg
                            anchors.fill: parent
                            radius: 12
                            color: passwordInput.activeFocus ? "#451a1e29" : "#300d111b"
                            border.color: passwordInput.activeFocus ? "#a07aa2f7" : "#50ffffff"
                            border.width: 1.6
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(
                                    1, -0.22, 0, 0,
                                    0,  1,    0, 0,
                                    0,  0,    1, 0,
                                    0,  0,    0, 1
                                )
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }

                        // Actual password text input
                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 52
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: "#ffffff"
                            font.pixelSize: 18
                            font.bold: true
                            selectionColor: "#807aa2f7"
                            clip: true
                            focus: root.uiActive

                            Text {
                                text: "Пароль"
                                color: "#75ffffff"
                                font.pixelSize: 15
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !passwordInput.text && !passwordInput.activeFocus
                            }

                            Keys.onPressed: (event) => {
                                root.resetActivity()
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.doLogin()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    root.uiActive = false
                                    event.accepted = true
                                }
                            }
                        }

                        // Submit Button
                        Rectangle {
                            id: submitBtn
                            width: 36
                            height: 36
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 9
                            color: submitMouse.containsMouse ? "#707aa2f7" : "#40ffffff"
                            border.color: "#60ffffff"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "→"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: 18
                            }

                            MouseArea {
                                id: submitMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.doLogin()
                            }
                        }
                    }

                    // Error text
                    Text {
                        id: errorMessage
                        text: ""
                        color: "#ff6e6e"
                        font.pixelSize: 12
                        font.bold: true
                        visible: text.length > 0
                    }
                }
            }

            // ============================================================
            // 4 BOTTOM BUTTONS UNDER AVATAR AND PASSWORD FIELD
            // ============================================================
            Row {
                spacing: 12
                anchors.left: parent.left
                anchors.leftMargin: 4

                // 1. Power Button (Windows-like popup menu)
                Rectangle {
                    id: powerBtn
                    width: 44
                    height: 36
                    radius: 8
                    color: (powerMouse.containsMouse || root.showPowerMenu) ? "#50ffffff" : "#25ffffff"
                    border.color: root.showPowerMenu ? "#a07aa2f7" : "#40ffffff"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "⏻"
                        color: "#ffffff"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.resetActivity()
                            root.showPowerMenu = !root.showPowerMenu
                        }
                    }

    // ============================================================
    // POWER POPUP MENU (Windows-like popup right above/under power button)
    // ============================================================
    Item {
        id: powerMenuContainer
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        z: 99

        visible: opacity > 0.01
        opacity: (root.uiActive && root.showPowerMenu) ? 1.0 : 0.0
        scale: (root.uiActive && root.showPowerMenu) ? 1.0 : 0.85
        transformOrigin: Item.TopLeft

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        Rectangle {
            width: 200
            height: powerColumn.implicitHeight + 20
            radius: 12
            color: "#ee161923"
            border.color: "#50ffffff"
            border.width: 1.5

            Column {
                id: powerColumn
                anchors.centerIn: parent
                spacing: 6

                // Shutdown
                Rectangle {
                    width: 176
                    height: 38
                    radius: 8
                    color: shutMouse.containsMouse ? "#40ff5555" : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 10
                        Text { text: "⏻"; color: "#ff6e6e"; font.pixelSize: 16 }
                        Text { text: "Выключение"; color: "#ffffff"; font.pixelSize: 13; font.bold: true }
                    }

                    MouseArea {
                        id: shutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof sddm !== "undefined" && sddm) sddm.powerOff()
                            else console.log("Mock PowerOff")
                        }
                    }
                }

                // Reboot
                Rectangle {
                    width: 176
                    height: 38
                    radius: 8
                    color: rebMouse.containsMouse ? "#407aa2f7" : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 10
                        Text { text: "↻"; color: "#7aa2f7"; font.pixelSize: 16 }
                        Text { text: "Перезагрузка"; color: "#ffffff"; font.pixelSize: 13; font.bold: true }
                    }

                    MouseArea {
                        id: rebMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof sddm !== "undefined" && sddm) sddm.reboot()
                            else console.log("Mock Reboot")
                        }
                    }
                }

                // Suspend
                Rectangle {
                    width: 176
                    height: 38
                    radius: 8
                    color: suspMouse.containsMouse ? "#40bb9af7" : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 10
                        Text { text: "☾"; color: "#bb9af7"; font.pixelSize: 16 }
                        Text { text: "Спящий режим"; color: "#ffffff"; font.pixelSize: 13; font.bold: true }
                    }

                    MouseArea {
                        id: suspMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof sddm !== "undefined" && sddm) sddm.suspend()
                            else console.log("Mock Suspend")
                        }
                    }
                }
            }
        }
    }


                }

                // 2. On-Screen Virtual Keyboard Button
                Rectangle {
                    id: vkBtn
                    width: 44
                    height: 36
                    radius: 8
                    color: (vkMouse.containsMouse || root.showVirtualKeyboard) ? "#50ffffff" : "#25ffffff"
                    border.color: root.showVirtualKeyboard ? "#a07aa2f7" : "#40ffffff"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "⌨"
                        color: "#ffffff"
                        font.pixelSize: 17
                    }

                    MouseArea {
                        id: vkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.resetActivity()
                            root.showVirtualKeyboard = !root.showVirtualKeyboard
                        }
                    }
                }

                // 3. Keyboard Layout Button
                Rectangle {
                    id: layoutBtn
                    width: layoutRow.implicitWidth + 20
                    height: 36
                    radius: 8
                    color: layoutMouse.containsMouse ? "#50ffffff" : "#25ffffff"
                    border.color: "#40ffffff"
                    border.width: 1

                    Row {
                        id: layoutRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "🌐"
                            font.pixelSize: 13
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.currentLayoutName
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: layoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleLayout()
                    }
                }

                // 4. Session Selector Button (e.g. Niri)
                Rectangle {
                    id: sessionBtn
                    width: sessionRow.implicitWidth + 20
                    height: 36
                    radius: 8
                    color: sessionMouse.containsMouse ? "#50ffffff" : "#25ffffff"
                    border.color: "#40ffffff"
                    border.width: 1

                    Row {
                        id: sessionRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "⚡"
                            font.pixelSize: 13
                            color: "#ffc777"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.currentSessionName
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: sessionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cycleSession()
                    }
                }
            }
        }
    }

    // ============================================================
    // FLOATING ON-SCREEN VIRTUAL KEYBOARD (Interactive & Draggable)
    // ============================================================
    Item {
        id: virtualKeyboardWindow
        width: 660
        height: 250
        x: Math.max(40, (parent.width - width) / 2)
        y: parent.height - height - 80

        visible: opacity > 0.01
        opacity: (root.uiActive && root.showVirtualKeyboard) ? 1.0 : 0.0
        scale: (root.uiActive && root.showVirtualKeyboard) ? 1.0 : 0.85

        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

        // Draggable background card
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#f0131622"
            border.color: "#60ffffff"
            border.width: 1.5

            // Top drag header
            Rectangle {
                id: vkHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 36
                radius: 14
                color: "#25ffffff"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌨ Экранная клавиатура (" + root.currentKeyboardLang + ")"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.bold: true
                }

                // Close button
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: closeVkMouse.containsMouse ? "#60ff5555" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: closeVkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showVirtualKeyboard = false
                    }
                }

                Drag.active: headerMouse.drag.active
                MouseArea {
                    id: headerMouse
                    anchors.fill: parent
                    anchors.rightMargin: 40
                    drag.target: virtualKeyboardWindow
                    drag.minimumX: 10
                    drag.maximumX: root.width - virtualKeyboardWindow.width - 10
                    drag.minimumY: 10
                    drag.maximumY: root.height - virtualKeyboardWindow.height - 10
                }
            }

            // Keyboard Keys Matrix
            Column {
                anchors.top: vkHeader.bottom
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                // Row 1: Numbers
                Row {
                    spacing: 5
                    Repeater {
                        model: root.isShiftActive ?
                            ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+"] :
                            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
                        delegate: KeyButton {
                            keyText: modelData
                            btnWidth: 44
                            onKeyClicked: root.appendPasswordChar(modelData)
                        }
                    }

                    // Backspace
                    KeyButton {
                        keyText: "⌫"
                        btnWidth: 56
                        isSpecial: true
                        onKeyClicked: root.backspacePassword()
                    }
                }

                // Row 2: Letters Row 1
                Row {
                    spacing: 5
                    Repeater {
                        model: {
                            if (root.currentKeyboardLang === "RU") {
                                return root.isShiftActive ?
                                    ["Й", "Ц", "У", "К", "Е", "Н", "Г", "Ш", "Щ", "З", "Х", "Ъ"] :
                                    ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ"]
                            } else {
                                return root.isShiftActive ?
                                    ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "{", "}"] :
                                    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]"]
                            }
                        }
                        delegate: KeyButton {
                            keyText: modelData
                            btnWidth: 44
                            onKeyClicked: root.appendPasswordChar(modelData)
                        }
                    }
                }

                // Row 3: Letters Row 2
                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: {
                            if (root.currentKeyboardLang === "RU") {
                                return root.isShiftActive ?
                                    ["Ф", "Ы", "В", "А", "П", "Р", "О", "Л", "Д", "Ж", "Э"] :
                                    ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "э"]
                            } else {
                                return root.isShiftActive ?
                                    ["A", "S", "D", "F", "G", "H", "J", "K", "L", ":", "\""] :
                                    ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"]
                            }
                        }
                        delegate: KeyButton {
                            keyText: modelData
                            btnWidth: 44
                            onKeyClicked: root.appendPasswordChar(modelData)
                        }
                    }

                    // Enter Key
                    KeyButton {
                        keyText: "⏎"
                        btnWidth: 64
                        isAccent: true
                        onKeyClicked: root.doLogin()
                    }
                }

                // Row 4: Shift + Letters Row 3
                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Shift button
                    KeyButton {
                        keyText: "⇧"
                        btnWidth: 60
                        isSpecial: true
                        isToggled: root.isShiftActive
                        onKeyClicked: root.isShiftActive = !root.isShiftActive
                    }

                    Repeater {
                        model: {
                            if (root.currentKeyboardLang === "RU") {
                                return root.isShiftActive ?
                                    ["Я", "Ч", "С", "М", "И", "Т", "Ь", "Б", "Ю", ","] :
                                    ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю", "."]
                            } else {
                                return root.isShiftActive ?
                                    ["Z", "X", "C", "V", "B", "N", "M", "<", ">", "?"] :
                                    ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]
                            }
                        }
                        delegate: KeyButton {
                            keyText: modelData
                            btnWidth: 44
                            onKeyClicked: root.appendPasswordChar(modelData)
                        }
                    }

                    // Clear button
                    KeyButton {
                        keyText: "Очистить"
                        btnWidth: 70
                        isSpecial: true
                        onKeyClicked: {
                            passwordInput.text = ""
                            root.resetActivity()
                        }
                    }
                }

                // Row 5: Space + Language Toggle
                Row {
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter

                    KeyButton {
                        keyText: root.currentKeyboardLang === "RU" ? "Язык: RU" : "Язык: EN"
                        btnWidth: 90
                        isSpecial: true
                        onKeyClicked: root.toggleLayout()
                    }

                    KeyButton {
                        keyText: "ПРОБЕЛ (SPACE)"
                        btnWidth: 320
                        onKeyClicked: root.appendPasswordChar(" ")
                    }

                    KeyButton {
                        keyText: "Скрыть"
                        btnWidth: 80
                        isSpecial: true
                        onKeyClicked: root.showVirtualKeyboard = false
                    }
                }
            }
        }
    }

    // KeyButton reusable delegate component
    component KeyButton: Rectangle {
        id: keyBtn
        property string keyText: ""
        property int btnWidth: 42
        property int btnHeight: 32
        property bool isSpecial: false
        property bool isAccent: false
        property bool isToggled: false
        signal keyClicked()

        width: btnWidth
        height: btnHeight
        radius: 6

        color: {
            if (isToggled) return "#807aa2f7"
            if (isAccent) return keyArea.containsMouse ? "#907aa2f7" : "#607aa2f7"
            if (isSpecial) return keyArea.containsMouse ? "#50ffffff" : "#25ffffff"
            return keyArea.containsMouse ? "#45ffffff" : "#20ffffff"
        }

        border.color: isToggled ? "#7aa2f7" : "#30ffffff"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: keyBtn.keyText
            color: "#ffffff"
            font.pixelSize: keyText.length > 3 ? 11 : 14
            font.bold: true
        }

        MouseArea {
            id: keyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: keyBtn.keyClicked()
        }
    }

    // Connections to SDDM signals
    Connections {
        target: (typeof sddm !== "undefined" && sddm) ? sddm : null

        function onLoginSucceeded() {
            errorMessage.color = "#80ff80"
            errorMessage.text = "Успешный вход..."
        }
        function onLoginFailed() {
            passwordInput.text = ""
            errorMessage.color = "#ff6e6e"
            errorMessage.text = "Неверный пароль"
            passwordInput.forceActiveFocus()
        }
        function onInformationMessage(message) {
            errorMessage.color = "#ffc777"
            errorMessage.text = message
        }
    }

    // Component Initialization
    Component.onCompleted: {
        updateLayoutLabel()
        updateSessionLabel()
        // Default to inactive state so video plays clean without blur
        root.uiActive = false
    }
}
