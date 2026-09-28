import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#89b4fa"
    property color sapphire: "#74c7ec"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"

    Process {
        id: themeReader
        command: ["bash", "-c", "cat ~/.cache/wal/colors.json 2>/dev/null || cat /tmp/qs_colors.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "" && txt !== "{}") {
                    try {
                        let data = JSON.parse(txt);
                        if (data.special) {
                            if (data.special.background) root.base = data.special.background;
                            if (data.special.background) root.mantle = data.special.background;
                            if (data.special.background) root.crust = data.special.background;
                            if (data.special.foreground) root.text = data.special.foreground;
                        }
                        if (data.colors) {
                            if (data.colors.color0) root.surface0 = data.colors.color0;
                            if (data.colors.color1) root.red = data.colors.color1;
                            if (data.colors.color2) root.green = data.colors.color2;
                            if (data.colors.color3) root.yellow = data.colors.color3;
                            if (data.colors.color4) root.blue = data.colors.color4;
                            if (data.colors.color5) root.mauve = data.colors.color5;
                            if (data.colors.color6) root.teal = data.colors.color6;
                            if (data.colors.color7) root.subtext0 = data.colors.color7;
                            if (data.colors.color8) root.surface1 = data.colors.color8;
                            if (data.colors.color9) root.surface2 = data.colors.color9;
                        }
                    } catch(e) {}
                }
            }
        }
    }

    Component.onCompleted: themeReader.running = true
}
