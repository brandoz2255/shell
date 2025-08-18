pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root

    required property var wrapper

    implicitWidth: layout.implicitWidth + Appearance.padding.normal * 2
    implicitHeight: layout.implicitHeight + Appearance.padding.normal * 2

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.spacing.normal

        StyledText {
            Layout.bottomMargin: Appearance.spacing.small / 2
            text: qsTr("Theme Mode")
            font.weight: 500
            color: Colours.palette.m3onSurface
        }

        // Button container with animated selector
        Item {
            Layout.preferredWidth: 208  // 100 + 100 + 8 spacing
            Layout.preferredHeight: 70

            // Background container
            StyledRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Colours.tPalette.m3surfaceContainer
            }

            // Animated selection indicator
            StyledRect {
                id: selector
                width: 100
                height: 70
                radius: Appearance.rounding.normal
                color: Colours.palette.m3primaryContainer
                x: Colours.light ? 0 : 104  // 100 + 4 spacing
                z: 1  // Behind the buttons
                
                // Subtle shadow for depth
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 2
                    radius: 8
                    samples: 17
                    color: Qt.rgba(0, 0, 0, 0.1)
                }

                Behavior on x {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Light mode button
            StyledRect {
                width: 100
                height: 70
                anchors.left: parent.left
                radius: Appearance.rounding.normal
                color: "transparent"
                z: 2  // Above the selector

                StateLayer {
                    anchors.fill: parent
                    color: Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    radius: Appearance.rounding.normal
                    
                    function onClicked(): void {
                        Colours.setMode("light");
                        root.wrapper.hasCurrent = false;
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.smaller

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "light_mode"
                        color: Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.large

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.durations.normal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Light")
                        color: Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.small

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.durations.normal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }
                    }
                }
            }

            // Dark mode button
            StyledRect {
                width: 100
                height: 70
                anchors.right: parent.right
                radius: Appearance.rounding.normal
                color: "transparent"
                z: 2  // Above the selector

                StateLayer {
                    anchors.fill: parent
                    color: !Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    radius: Appearance.rounding.normal
                    
                    function onClicked(): void {
                        Colours.setMode("dark");
                        root.wrapper.hasCurrent = false;
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.smaller

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "dark_mode"
                        color: !Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.large

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.durations.normal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Dark")
                        color: !Colours.light ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.small

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.durations.normal
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.anim.curves.standard
                            }
                        }
                    }
                }
            }
        }
    }
}