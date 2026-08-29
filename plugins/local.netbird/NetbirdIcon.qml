import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool connected: false
  property bool connecting: false
  property bool needsLogin: false
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

    // Geometric Origami NetBird
    Shape {
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4

      // Top Wing / Primary Feathers
      ShapePath {
        fillColor: root.color
        strokeColor: root.color
        strokeWidth: 0.5
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        PathSvg {
          path: "M 7 9 L 20 2 L 15 10 Z"
        }
      }

      // Middle Body & Beak
      ShapePath {
        fillColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.9)
        strokeColor: root.color
        strokeWidth: 0.5
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        PathSvg {
          path: "M 2 11 L 7 9 L 15 10 L 10 16 Z"
        }
      }

      // Lower Wing / Back
      ShapePath {
        fillColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.75)
        strokeColor: root.color
        strokeWidth: 0.5
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        PathSvg {
          path: "M 15 10 L 22 10 L 16 16 Z"
        }
      }

      // Tail
      ShapePath {
        fillColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.85)
        strokeColor: root.color
        strokeWidth: 0.5
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        PathSvg {
          path: "M 10 16 L 8 22 L 5 18 L 6 13 Z"
        }
      }
    }

    // Status Dot / Badge (Bottom Right)
    Rectangle {
      visible: root.showBadge && (root.connected || root.connecting || root.needsLogin)
      width: 7
      height: 7
      radius: 3.5
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      color: root.needsLogin ? Color.urgent : (root.connecting ? Color.accent : (root.connected ? "#2ecc71" : "transparent"))
      border.width: 1.2
      border.color: Color.background

      SequentialAnimation on opacity {
        running: root.connecting
        loops: Animation.Infinite
        NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
      }
    }
  }
}
