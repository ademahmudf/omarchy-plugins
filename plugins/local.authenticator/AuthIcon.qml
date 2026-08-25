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

        // Outer Shield
        PathSvg {
          path: "M 12 2 L 4 5 L 4 11 C 4 16.5 7.4 21.5 12 22.8 C 16.6 21.5 20 16.5 20 11 L 20 5 Z"
        }
      }

      ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: 0

        // Inner Check / Key dot
        PathSvg {
          path: "M 12 7.5 C 10.6 7.5 9.5 8.6 9.5 10 C 9.5 10.9 10 11.7 10.8 12.1 L 10.8 15.5 C 10.8 16.1 11.3 16.6 12 16.6 C 12.7 16.6 13.2 16.1 13.2 15.5 L 13.2 12.1 C 14 11.7 14.5 10.9 14.5 10 C 14.5 8.6 13.4 7.5 12 7.5 Z"
        }
      }
    }
  }
}
