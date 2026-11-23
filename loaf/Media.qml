// Loaf media pill for the bar: cover, title and artist, previous / play-pause / next. Reads MPRIS (Spotify, Brave
// tabs, anything that plays); only signals from the players move it, no timer (position is never read, so Quickshell
// never asks for it). Shows the player that is playing, else a paused one, else any open player (stopped too):
// it stays up while a player app is open, so the DJ can always start the next song. Gone only with no player.
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Shapes

Row {
    id: media
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying)
        || players.find(p => p.playbackState === MprisPlaybackState.Paused) || players[0] || null
    visible: !!player
    spacing: 0

    component Glyph: Rectangle { // one round button with an SVG path drawn in ink, 16 x 16 box
        id: g
        property string path
        property bool on: true
        signal clicked()
        width: 26; height: 26; radius: 13
        anchors.verticalCenter: parent.verticalCenter
        color: area.containsMouse && on ? Theme.fill : "transparent"
        Shape {
            x: 5; y: 5; width: 16; height: 16
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: g.on ? Theme.ink : Theme.faint; PathSvg { path: g.path } }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; enabled: g.on; cursorShape: Qt.PointingHandCursor; onClicked: g.clicked() }
    }

    Item { // cover and words; a click raises the player's window when it can
        width: words.x + words.width + 6; height: 26
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            id: cover
            visible: art.status === Image.Ready
            width: visible ? 18 : 0; height: 18; radius: 4; clip: true
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.fill
            Image { id: art; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; sourceSize { width: 36; height: 36 }
                    source: media.player ? media.player.trackArtUrl : "" }
        }
        Text {
            id: words
            x: cover.width ? cover.width + 8 : 0
            width: Math.min(implicitWidth, 240); elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.StyledText
            text: !media.player ? "" : esc(media.player.trackTitle || media.player.identity)
                  + (media.player.trackArtist ? " <font color='" + Theme.mute + "'>" + esc(media.player.trackArtist) + "</font>" : "")
            function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;") }
            color: Theme.ink; font { family: Theme.sans; pixelSize: 13 }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: media.player && media.player.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (media.player && media.player.canRaise) media.player.raise()
        }
    }
    Glyph { on: !!media.player && media.player.canGoPrevious; onClicked: media.player.previous()
            path: "M3 3h2v10H3z M13 3v10L6 8z" }
    Glyph { on: !!media.player && media.player.canTogglePlaying; onClicked: media.player.togglePlaying()
            path: media.player && media.player.isPlaying ? "M4 3h3v10H4z M9 3h3v10H9z" : "M4.5 2.5v11L13 8z" }
    Glyph { on: !!media.player && media.player.canGoNext; onClicked: media.player.next()
            path: "M11 3h2v10h-2z M3 3v10l7-5z" }
}
