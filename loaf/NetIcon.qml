// Network mark for the bar, drawn as vectors (sharp at any scale, follows light/dark):
// "wifi" with 1 to 3 arcs by signal strength, "cable" for a wired link (the dock), "none" for no connection.
import QtQuick
import QtQuick.Shapes

Item {
    id: icon
    property string kind: "none"   // wifi | cable | none
    property real strength: 1      // 0..1, Wi-Fi signal
    property color ink: Theme.ink
    property color dim: Theme.faint
    width: 16; height: 16

    // Wi-Fi (also the base of "none"): a dot and three arcs opening upwards from the bottom centre
    Shape {
        anchors.fill: parent
        visible: icon.kind !== "cable"
        preferredRendererType: Shape.CurveRenderer
        ShapePath { // arc 1 of 3
            strokeColor: icon.kind === "wifi" && icon.strength > 0/3 ? icon.ink : icon.dim
            strokeWidth: 1.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: 4.82; startY: 10.82
            PathArc { x: 11.18; y: 10.82; radiusX: 4.5; radiusY: 4.5 }
        }
        ShapePath { // arc 2 of 3
            strokeColor: icon.kind === "wifi" && icon.strength > 1/3 ? icon.ink : icon.dim
            strokeWidth: 1.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: 2.34; startY: 8.34
            PathArc { x: 13.66; y: 8.34; radiusX: 8.0; radiusY: 8.0 }
        }
        ShapePath { // arc 3 of 3
            strokeColor: icon.kind === "wifi" && icon.strength > 2/3 ? icon.ink : icon.dim
            strokeWidth: 1.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: -0.13; startY: 5.87
            PathArc { x: 16.13; y: 5.87; radiusX: 11.5; radiusY: 11.5 }
        }
        ShapePath { // the dot
            strokeColor: "transparent"
            fillColor: icon.kind === "wifi" ? icon.ink : icon.dim
            startX: 8; startY: 12.4
            PathArc { x: 8; y: 15.6; radiusX: 1.6; radiusY: 1.6 }
            PathArc { x: 8; y: 12.4; radiusX: 1.6; radiusY: 1.6 }
        }
    }

    // no connection: a slash across the faint arcs
    Shape {
        anchors.fill: parent
        visible: icon.kind === "none"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.ink; strokeWidth: 1.6; capStyle: ShapePath.RoundCap; fillColor: "transparent"
            startX: 2.5; startY: 2.5
            PathLine { x: 13.5; y: 13.5 }
        }
    }

    // cable: an Ethernet plug (body with a latch) and its cable
    Shape {
        anchors.fill: parent
        visible: icon.kind === "cable"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.ink; strokeWidth: 1.5; fillColor: "transparent"; joinStyle: ShapePath.RoundJoin
            startX: 3; startY: 2.5
            PathLine { x: 13; y: 2.5 }
            PathLine { x: 13; y: 9.5 }
            PathLine { x: 10.5; y: 9.5 }
            PathLine { x: 10.5; y: 11.5 }
            PathLine { x: 5.5; y: 11.5 }
            PathLine { x: 5.5; y: 9.5 }
            PathLine { x: 3; y: 9.5 }
            PathLine { x: 3; y: 2.5 }
        }
        ShapePath { // the contacts
            strokeColor: icon.ink; strokeWidth: 1.2; capStyle: ShapePath.RoundCap; fillColor: "transparent"
            startX: 6; startY: 4.5; PathLine { x: 6; y: 6.5 }
            PathMove { x: 8; y: 4.5 }  PathLine { x: 8; y: 6.5 }
            PathMove { x: 10; y: 4.5 } PathLine { x: 10; y: 6.5 }
        }
        ShapePath { // the cable
            strokeColor: icon.ink; strokeWidth: 1.5; capStyle: ShapePath.RoundCap; fillColor: "transparent"
            startX: 8; startY: 11.5
            PathLine { x: 8; y: 15 }
        }
    }
}
