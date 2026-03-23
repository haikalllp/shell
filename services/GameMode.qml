pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Caelestia
import qs.services
import qs.config
import qs.utils

Singleton {
    id: root

    property bool enabled: false

    function setDynamicConfs(): void {
        Hypr.extras.applyOptions({
            "animations:enabled": 0,
            "decoration:shadow:enabled": 0,
            "decoration:blur:enabled": 0,
            "general:gaps_in": 0,
            "general:gaps_out": 0,
            "general:border_size": 1,
            "decoration:rounding": 0
            //"general:allow_tearing": 1
        });
        Hypr.extras.message("keyword windowrule opacity 1 override 1 override 1 override, match:title .*");
    }

    function saveState(): void {
        const jsonContent = JSON.stringify({
            enabled: root.enabled
        });
        writeProcess.script = `mkdir -p ${Paths.state} && echo '${jsonContent}' > ${Paths.state}/gamemode.json`;
        writeProcess.running = true;
    }

    onEnabledChanged: {
        if (enabled) {
            setDynamicConfs();
            if (Config.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode enabled"), qsTr("Disabled Hyprland animations, blur, gaps and shadows"), "gamepad");
        } else {
            Hypr.extras.message("reload");
            if (Config.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode disabled"), qsTr("Hyprland settings restored"), "gamepad");
        }
        saveState();
    }

    Process {
        id: writeProcess

        property string script: ""

        command: ["bash", "-c", script]
        // qmllint disable signal-handler-parameters
        onExited: function (exitCode) {
            if (exitCode !== 0)
                console.warn("GameMode: Failed to save gamemode state, exit code:" + exitCode);
        }
        // qmllint enable signal-handler-parameters
    }

    FileView {
        path: `${Paths.state}/gamemode.json`
        printErrors: false
        onLoaded: {
            try {
                root.enabled = JSON.parse(text()).enabled;
            } catch (e) {
                console.warn("GameMode: Failed to load gamemode state:", e);
            }
        }
        Component.onCompleted: reload()
    }

    Connections {
        function onConfigReloaded(): void {
            if (root.enabled)
                root.setDynamicConfs();
        }

        target: Hypr
    }

    IpcHandler {
        function isEnabled(): bool {
            return root.enabled;
        }

        function toggle(): void {
            root.enabled = !root.enabled;
        }

        function enable(): void {
            root.enabled = true;
        }

        function disable(): void {
            root.enabled = false;
        }

        target: "gameMode"
    }
}
