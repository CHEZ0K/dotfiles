import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "."

Item {
    id: window
    width: Screen.width
    height: Screen.height

    Caching { id: paths }

    Scaler {
        id: scaler
        currentWidth: Screen.width
        currentHeight: Screen.height
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    MatugenColors { id: _theme }

    property string targetWallName: ""
    property bool initialFocusSet: false
    property int scrollAccum: 0
    readonly property real scrollThreshold: window.s(120)

    property bool isApplying: false
    
    Timer {
        id: applyUnlockTimer
        interval: 250
        onTriggered: window.isApplying = false
    }
    
    property bool isStartup: localFolderModel.status === FolderListModel.Loading
    property bool isReady: visible && localFolderModel.status === FolderListModel.Ready

    function cancelAndClose() {
        Quickshell.execDetached(["bash", "-c", "rm -f /tmp/qs_selected_wallpaper; sleep 0.05; kill -9 " + Quickshell.processId]);
    }

    function applyWallpaper(safeFileName) {
        if (!safeFileName || window.isApplying) return;
        window.isApplying = true;
        applyUnlockTimer.restart();
        
        let target = "";
        if (safeFileName.startsWith("WPE_")) {
            target = "WPE:" + safeFileName;
        } else {
            let cleanName = window.getCleanName(safeFileName);
            target = window.srcDir + "/" + cleanName;
        }
        
        Quickshell.execDetached(["bash", "-c", "echo '" + target + "' > /tmp/qs_selected_wallpaper; sleep 0.05; kill -9 " + Quickshell.processId]);
    }

    function getCleanName(name) {
        if (!name) return "";
        let clean = String(name);
        return clean.startsWith("000_") ? clean.substring(4) : clean;
    }

    readonly property string thumbDir: {
        let envD = Quickshell.env("PREVIEW_DIR");
        if (envD && envD !== "") return "file://" + envD;
        return "file://" + Quickshell.env("HOME") + "/.cache/hypr/wallpaper_previews";
    }

    readonly property string srcDir: {
        let envS = Quickshell.env("WALLPAPER_DIR");
        if (envS && envS !== "") return envS;
        return Quickshell.env("HOME") + "/67";
    }

    function getSafeUrl(fName) {
        if (!fName) return "";
        let rawPath = decodeURIComponent(window.thumbDir.replace(/^file:\/\//, "")) + "/" + fName;
        return encodeURI("file://" + rawPath);
    }

    readonly property real itemWidth: window.s(420)
    readonly property real itemHeight: window.s(440)
    readonly property real spacing: window.s(14)
    readonly property real skewFactor: -0.35

    Timer {
        id: scrollThrottle
        interval: 40
    }

    Shortcut { 
        sequence: "Left"
        enabled: !window.isApplying
        onActivated: {
            if (view.currentIndex > 0) view.currentIndex--;
            else view.currentIndex = localProxyModel.count - 1;
        }
    }
    Shortcut { 
        sequence: "Right"
        enabled: !window.isApplying
        onActivated: {
            if (view.currentIndex < localProxyModel.count - 1) view.currentIndex++;
            else view.currentIndex = 0;
        }
    }
    
    Shortcut { 
        sequence: "Return"
        enabled: !window.isApplying
        onActivated: { 
            if (view.currentIndex >= 0 && view.currentIndex < localProxyModel.count) {
                let fname = localProxyModel.get(view.currentIndex).fileName;
                if (fname) window.applyWallpaper(String(fname));
            }
        } 
    }
    
    Shortcut { 
        sequence: "Escape"
        enabled: !window.isApplying
        onActivated: window.cancelAndClose()
    }

    ListModel { id: localProxyModel }

    FolderListModel {
        id: localFolderModel
        folder: window.thumbDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm", ".*.jpg", ".*.jpeg", ".*.png", ".*.webp", ".*.gif", ".*.mp4", ".*.mkv", ".*.mov", ".*.webm", ". *.jpg", ". *.jpeg", ". *.png", ". *.webp", ". *.gif", ". *.mp4", ". *.mkv"]
        showDirs: false
        showHidden: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        
        onCountChanged: window.syncLocalModel()
        onStatusChanged: { if (status === FolderListModel.Ready) window.syncLocalModel() }
    }

    property int _localSyncedCount: 0

    function syncLocalModel() {
        let folderCount = localFolderModel.count;
        if (folderCount < window._localSyncedCount) {
            localProxyModel.clear();
            window._localSyncedCount = 0;
        }

        if (folderCount > window._localSyncedCount) {
            let batch = [];
            for (let i = window._localSyncedCount; i < folderCount; i++) {
                let fn = localFolderModel.get(i, "fileName");
                let fu = localFolderModel.get(i, "fileUrl");
                if (fn !== undefined) {
                    batch.push({ "fileName": fn, "fileUrl": String(fu) });
                }
            }
            if (batch.length > 0) {
                localProxyModel.append(batch);
            }
            window._localSyncedCount = folderCount;
        }

        if (!window.initialFocusSet && localProxyModel.count > 0) {
            view.currentIndex = 0;
            window.initialFocusSet = true;
        }
    }

    ListView {
        id: view
        anchors.fill: parent
        
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

        spacing: 0
        orientation: ListView.Horizontal
        clip: false

        interactive: !window.isApplying
        cacheBuffer: 2000

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((window.itemWidth * 1.55 + window.spacing) / 2)
        preferredHighlightEnd: (width / 2) + ((window.itemWidth * 1.55 + window.spacing) / 2)
        
        highlightMoveDuration: window.initialFocusSet ? 280 : 0
        focus: true

        Keys.onReturnPressed: (event) => {
            if (view.currentIndex >= 0 && view.currentIndex < localProxyModel.count) {
                let fname = localProxyModel.get(view.currentIndex).fileName;
                if (fname) {
                    window.applyWallpaper(String(fname));
                    event.accepted = true;
                }
            }
        }
        Keys.onEnterPressed: (event) => {
            if (view.currentIndex >= 0 && view.currentIndex < localProxyModel.count) {
                let fname = localProxyModel.get(view.currentIndex).fileName;
                if (fname) {
                    window.applyWallpaper(String(fname));
                    event.accepted = true;
                }
            }
        }
        Keys.onEscapePressed: (event) => {
            window.cancelAndClose();
            event.accepted = true;
        }

        header: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.55) / 2)) }
        footer: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.55) / 2)) }

        model: localProxyModel

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton

            onWheel: (wheel) => {
                if (window.isApplying) {
                    wheel.accepted = true;
                    return;
                }

                if (scrollThrottle.running) {
                   wheel.accepted = true;
                   return;
                }

                let dx = wheel.angleDelta.x;
                let dy = wheel.angleDelta.y;
                let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;

                scrollAccum += delta;

                if (Math.abs(scrollAccum) >= scrollThreshold) {
                    if (scrollAccum > 0) {
                        if (view.currentIndex > 0) view.currentIndex--;
                        else view.currentIndex = localProxyModel.count - 1;
                    } else {
                        if (view.currentIndex < localProxyModel.count - 1) view.currentIndex++;
                        else view.currentIndex = 0;
                    }
                    scrollAccum = 0;
                    scrollThrottle.start();
                }

                wheel.accepted = true;
            }        
        }

        delegate: Item {
            id: delegateRoot
            
            readonly property string safeFileName: fileName !== undefined ? String(fileName) : ""
            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isVisuallyEnlarged: isCurrent
            readonly property bool isVideo: safeFileName.startsWith("000_")
            
            readonly property real targetWidth: isVisuallyEnlarged ? (window.itemWidth * 1.55) : (window.itemWidth * 0.48)
            readonly property real targetHeight: isVisuallyEnlarged ? (window.itemHeight + window.s(38)) : window.itemHeight

            // Enhanced realistic plastic card toss physics
            property real flickAngle: 0
            property real flickY: 0
            property real flickScale: isVisuallyEnlarged ? 1.0 : 0.94

            onIsVisuallyEnlargedChanged: {
                if (isVisuallyEnlarged && window.initialFocusSet) {
                    flickAngle = (index % 2 === 0 ? -6.5 : 6.5);
                    flickY = -window.s(22);
                    flickScale = 1.05;
                    flickReturnAnim.restart();
                } else {
                    flickAngle = 0;
                    flickY = 0;
                    flickScale = 0.94;
                }
            }

            ParallelAnimation {
                id: flickReturnAnim
                NumberAnimation {
                    target: delegateRoot
                    property: "flickAngle"
                    to: 0
                    duration: 320
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.0
                }
                NumberAnimation {
                    target: delegateRoot
                    property: "flickY"
                    to: 0
                    duration: 320
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.8
                }
                NumberAnimation {
                    target: delegateRoot
                    property: "flickScale"
                    to: 1.0
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }

            width: targetWidth + window.spacing
            height: targetHeight
            opacity: isVisuallyEnlarged ? 1.0 : 0.52
            z: isVisuallyEnlarged ? 30 : 1

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.verticalCenterOffset: window.s(15)

            Behavior on width { enabled: window.initialFocusSet; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: window.initialFocusSet; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on opacity { enabled: window.initialFocusSet; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            Item {
                id: cardContainer
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: ((window.itemHeight - height) / 2) * window.skewFactor
                
                width: parent.width > 0 ? parent.width * (targetWidth / (targetWidth + window.spacing)) : 0
                height: parent.height
                y: delegateRoot.flickY
                scale: delegateRoot.flickScale

                transform: [
                    Matrix4x4 {
                        property real s: window.skewFactor
                        matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    },
                    Rotation {
                        origin.x: cardContainer.width / 2
                        origin.y: cardContainer.height / 2
                        angle: delegateRoot.flickAngle
                    }
                ]
                
                // Deep dynamic plastic card drop shadow
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: isVisuallyEnlarged ? window.s(-12) : window.s(-3)
                    radius: window.s(22)
                    color: isVisuallyEnlarged ? Qt.rgba(0, 0, 0, 0.72) : Qt.rgba(0, 0, 0, 0.3)
                    z: -1
                    Behavior on anchors.margins { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 280 } }
                }

                // Plastic Card Body
                Rectangle {
                    id: cardBody
                    anchors.fill: parent
                    radius: window.s(16)
                    color: _theme.base
                    clip: true
                    
                    border.width: isVisuallyEnlarged ? window.s(3.0) : window.s(1.2)
                    border.color: isVisuallyEnlarged ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.15)
                    Behavior on border.width { NumberAnimation { duration: 200 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.currentIndex = index;
                            window.applyWallpaper(delegateRoot.safeFileName);
                        }
                    }

                    // Card Wallpaper Image
                    Image {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: window.s(-50)
                        width: (window.itemWidth * 1.55) + ((window.itemHeight + window.s(38)) * Math.abs(window.skewFactor)) + window.s(55)
                        height: window.itemHeight + window.s(38)
                        fillMode: Image.PreserveAspectCrop
                        source: window.getSafeUrl(delegateRoot.safeFileName)
                        asynchronous: true
                        smooth: true
                        mipmap: true

                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                    }

                    // Glossy plastic card sheen reflection
                    Rectangle {
                        anchors.fill: parent
                        radius: window.s(16)
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: isVisuallyEnlarged ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.05) }
                            GradientStop { position: 0.35; color: isVisuallyEnlarged ? Qt.rgba(1, 1, 1, 0.04) : "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
                        }
                    }

                    // Video Badge Icon if video
                    Rectangle {
                        visible: delegateRoot.isVideo
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: window.s(12)
                        width: window.s(34)
                        height: window.s(34)
                        radius: window.s(8)
                        color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.8)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.3)
                        
                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                        
                        Canvas {
                            anchors.fill: parent
                            anchors.margins: window.s(9)
                            onPaint: {
                                var ctx = getContext("2d");
                                var s = window.s;
                                ctx.reset();
                                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.95);
                                ctx.beginPath();
                                ctx.moveTo(s(4), 0);
                                ctx.lineTo(s(14), s(8));
                                ctx.lineTo(s(4), s(16));
                                ctx.closePath();
                                ctx.fill();
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        view.forceActiveFocus();
    }
}
