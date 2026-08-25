import QtQuick
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  implicitWidth: Math.round(iconSize)
  implicitHeight: Math.round(iconSize)
  width: Math.round(iconSize)
  height: Math.round(iconSize)

  // Outer circle "o"
  Rectangle {
    id: outerCircle
    anchors.centerIn: parent
    width: Math.max(10, Math.round(root.iconSize * 0.84))
    height: width
    radius: width / 2
    color: "transparent"
    border.width: Math.max(1.5, Math.round(root.iconSize * 0.12))
    border.color: root.color

    // Inner dot "."
    Rectangle {
      anchors.centerIn: parent
      width: Math.max(3.5, Math.round(outerCircle.width * 0.38))
      height: width
      radius: width / 2
      color: root.color
    }
  }
}
