// Battery mark for the bar: an outline filled to the charge, a bolt in front of it while charging,
// red below 10% on battery. Plain rectangles plus one vector bolt, so it is sharp at any scale.
import QtQuick
import QtQuick.Shapes

Item {
    id: icon
    property real level: 1          // 0..1
    property bool charging: false
    readonly property bool low: !charging && level <= 0.1
    readonly property color ink: low ? "#B4534B" : Theme.ink
    readonly property real lead: charging ? 10 : 0 // room for the bolt
    width: lead + 22; height: 12

    Rectangle { // body
        id: body
        x: icon.lead
        width: 19; height: 12; radius: 3.5
        color: "transparent"; border { width: 1.3; color: icon.ink }
        Rectangle { // charge
            x: 2.5; y: 2.5; height: parent.height - 5; radius: 1.5
            width: Math.max(1.5, (parent.width - 5) * Math.min(1, icon.level))
            color: icon.ink
        }
    }
    Rectangle { // nub
        x: icon.lead + 19.8; y: 4; width: 1.8; height: 4; radius: 1
        color: icon.ink
    }
    Shape { // bolt in front of the battery while charging
        visible: icon.charging
        width: 8; height: 12
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: icon.ink
            strokeColor: icon.ink; strokeWidth: 0.6; joinStyle: ShapePath.RoundJoin
            startX: 5.6; startY: 0
            PathLine { x: 0.6; y: 6.8 }
            PathLine { x: 3.8; y: 6.8 }
            PathLine { x: 2.6; y: 12 }
            PathLine { x: 7.6; y: 5.0 }
            PathLine { x: 4.4; y: 5.0 }
            PathLine { x: 5.6; y: 0 }
        }
    }
}
