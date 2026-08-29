import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property string soundMode: "anc" // "anc" | "ambient" | "off" | "disconnected"
  property bool connected: true
  property int battery: -1
  property bool showBadge: true

  implicitWidth: Math.round(iconSize)
  implicitHeight: Math.round(iconSize)
  width: Math.round(iconSize)
  height: Math.round(iconSize)

  Item {
    id: scaler
    width: 24
    height: 24
    anchors.centerIn: parent
    scale: root.iconSize / 24
    transformOrigin: Item.Center

    // Modern Over-Ear Headphone Base
    Shape {
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4

      // Headband Arc
      ShapePath {
        fillColor: "transparent"
        strokeColor: root.connected ? root.color : Qt.rgba(root.color.r, root.color.g, root.color.b, 0.4)
        strokeWidth: 2.2
        capStyle: ShapePath.RoundCap

        PathAngleArc {
          centerX: 12
          centerY: 12
          radiusX: 8.5
          radiusY: 8.5
          startAngle: -180
          sweepAngle: 180
        }
      }

      // Left Earcup
      ShapePath {
        fillColor: root.connected ? root.color : Qt.rgba(root.color.r, root.color.g, root.color.b, 0.4)
        strokeColor: "transparent"
        strokeWidth: 0

        PathSvg {
          path: "M 3.5 11 C 2.5 11 2 12 2 13.5 L 2 17.5 C 2 19 2.5 20 3.5 20 C 4.5 20 5.5 19 5.5 17.5 L 5.5 13.5 C 5.5 12 4.5 11 3.5 11 Z"
        }
      }

      // Right Earcup
      ShapePath {
        fillColor: root.connected ? root.color : Qt.rgba(root.color.r, root.color.g, root.color.b, 0.4)
        strokeColor: "transparent"
        strokeWidth: 0

        PathSvg {
          path: "M 20.5 11 C 19.5 11 18.5 12 18.5 13.5 L 18.5 17.5 C 18.5 19 19.5 20 20.5 20 C 21.5 20 22 19 22 17.5 L 22 13.5 C 22 12 21.5 11 20.5 11 Z"
        }
      }
    }

    // Ambient Sound Waves (Center)
    Shape {
      visible: root.connected && root.soundMode === "ambient"
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4

      ShapePath {
        fillColor: "transparent"
        strokeColor: Color.accent
        strokeWidth: 1.4
        capStyle: ShapePath.RoundCap

        PathSvg {
          path: "M 9 13.5 Q 12 11.5 15 13.5 M 10 16.5 Q 12 15 14 16.5"
        }
      }
    }

    // ANC Shield Icon (Center)
    Shape {
      visible: root.connected && root.soundMode === "anc"
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4

      ShapePath {
        fillColor: Color.accent
        strokeColor: "transparent"
        strokeWidth: 0

        PathSvg {
          path: "M 12 10 L 14.5 11.5 L 14.5 14.5 C 14.5 16.5 12 18 12 18 C 12 18 9.5 16.5 9.5 14.5 L 9.5 11.5 Z"
        }
      }
    }

    // Status / Mode Dot (Bottom Right)
    Rectangle {
      visible: root.showBadge && root.connected
      width: 6
      height: 6
      radius: 3
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      color: root.soundMode === "anc" ? "#2ecc71" : (root.soundMode === "ambient" ? Color.accent : Qt.darker(Color.foreground, 1.8))
      border.width: 1
      border.color: Color.background
    }
  }
}
