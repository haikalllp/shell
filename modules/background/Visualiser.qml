pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    readonly property bool shouldBeActive: Config.background.visualiser.enabled && (!Config.background.visualiser.autoHide || (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true))
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    opacity: shouldBeActive ? 1 : 0

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.opacity > 0 && Config.background.visualiser.blur

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        layer.enabled: true

        Loader {
            asynchronous: true
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.opacity > 0

            sourceComponent: Config.background.visualiser.gpu ? gpuComp : cpuComp
        }
    }

    Component {
        id: cpuComp

        Item {
            ServiceRef {
                service: Audio.cava
            }

            VisualiserBars {
                id: bars

                anchors.fill: parent
                anchors.margins: Config.border.thickness
                anchors.leftMargin: (ShellState.componentsFor(root.screen)?.bar?.exclusiveZone ?? 0) + Tokens.spacing.small * Config.background.visualiser.spacing

                values: Audio.cava.values
                primaryColor: Qt.alpha(Colours.palette.m3primary, 0.7)
                secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)
                rounding: Tokens.rounding.medium * Config.background.visualiser.rounding
                spacing: Tokens.spacing.extraSmall * Config.background.visualiser.spacing
                animationDuration: Tokens.anim.durations.normal

                Behavior on anchors.leftMargin {
                    Anim {}
                }
            }

            FrameAnimation {
                running: root.opacity > 0 && !bars.settled
                onTriggered: bars.advance(frameTime)
            }
        }
    }

    Component {
        id: gpuComp

        Item {
            id: gpu

            readonly property var values: Audio.cava.values
            readonly property int barCount: values.length
            readonly property real dpr: (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1

            ServiceRef {
                service: Audio.cava
            }

            Item {
                id: encoder

                visible: false
                width: Math.max(gpu.barCount, 1)
                height: 1

                Repeater {
                    model: gpu.barCount

                    Rectangle {
                        required property int index

                        width: 1
                        height: 1
                        color: {
                            const v = Math.min(Math.max(gpu.values[index] ?? 0, 0), 1);
                            const x = Math.round(v * 65535);
                            return Qt.rgba(Math.floor(x / 256) / 255, (x % 256) / 255, 0, 1);
                        }
                    }
                }
            }

            ShaderEffectSource {
                id: tex

                sourceItem: encoder
                textureSize: Qt.size(Math.max(gpu.barCount, 1), 1)
                smooth: false
                live: false
            }

            Connections {
                target: Audio.cava

                function onValuesChanged(): void {
                    tex.scheduleUpdate();
                }
            }

            ShaderEffect {
                anchors.fill: parent
                anchors.margins: Config.border.thickness
                anchors.leftMargin: (ShellState.componentsFor(root.screen)?.bar?.exclusiveZone ?? 0) + Tokens.spacing.small * Config.background.visualiser.spacing

                Behavior on anchors.leftMargin {
                    Anim {}
                }

                property var dataTex: tex
                property real itemWidth: width
                property real itemHeight: height
                property int barCount: gpu.barCount
                property real rounding: Tokens.rounding.medium * Config.background.visualiser.rounding
                property real spacing: Tokens.spacing.extraSmall * Config.background.visualiser.spacing
                property real dpr: gpu.dpr
                property color primaryColor: Qt.alpha(Colours.palette.m3primary, 0.7)
                property color secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)

                fragmentShader: "qrc:/shaders/visualiser.frag.qsb"
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
