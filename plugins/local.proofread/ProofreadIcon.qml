import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

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

    Shape {
      anchors.fill: parent
      layer.enabled: true
      layer.samples: 4

      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: 1.8
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        // Fountain pen / quill nib
        PathSvg {
          path: "M 18 2 L 22 6 L 8 20 L 2 22 L 4 16 Z"
        }
      }

      ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: 0

        // Sparkle / Star dot
        PathSvg {
          path: "M 19 12 C 19 13.5 20.5 15 22 15 C 20.5 15 19 16.5 19 18 C 19 16.5 17.5 15 16 15 C 17.5 15 19 13.5 19 12 Z"
        }
      }
    }
  }
}
