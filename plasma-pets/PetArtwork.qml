import QtQuick
import "Frames.js" as Frames
import "Silhouettes.js" as Silhouettes

Item {
    id: sprite
    required property string kind
    required property string activity
    required property int facing
    // The rectangles in the atlases include margins around the artwork.
    readonly property bool robot: kind === "codex"
    readonly property int row: {
        switch (activity) {
        case "walk": return facing > 0 ? 1 : 2
        case "wave": case "pet": return 3
        case "air": case "dance": return 4
        case "squash": return 5
        case "sleep": return 6
        case "work": return 7
        case "dizzy": return 8
        default: return 0
        }
    }
    readonly property string clipName: {
        switch (activity) {
        case "walk": return "walk"
        case "pet": case "wave": return "wave"
        case "air": return "jump"
        case "dance": case "dizzy": case "ball": case "trumpet": case "detective": return activity
        default: return "idle"
        }
    }
    readonly property var robotTiming: [
        [1680,660,660,840,840,1920], [120,120,120,120,120,120,120,220],
        [120,120,120,120,120,120,120,220], [140,140,140,280],
        [140,140,140,140,280], [140,140,140,140,140,140,140,240],
        [150,150,150,150,150,260], [120,120,120,120,120,220], [150,150,150,150,150,280]
    ]
    readonly property var timing: robot ? robotTiming[row] : Frames.clawd[clipName]
    property int frame: 0
    readonly property bool catSleeping: kind === "cat" && (activity === "sleep" || activity === "doze")
    readonly property string shapeKey: catSleeping ? "catSleep" : kind === "cat" ? "cat" : robot ? "robot"+row : clipName
    readonly property var pose: Silhouettes.poses[Silhouettes.byClip[shapeKey][frame] ?? Silhouettes.byClip[shapeKey][0]]
    readonly property bool mirrored: !robot && facing < 0
    onTimingChanged: frame = 0
    Timer {
        id: clock
        running: sprite.visible && sprite.kind !== "cat" && sprite.timing.length > 1
        repeat: true
        interval: sprite.timing[sprite.frame] || 90
        onTriggered: {
            if (sprite.kind === "cat" || sprite.timing.length < 2) { stop(); return }
            sprite.frame = (sprite.frame + 1) % sprite.timing.length
        }
    }
    Image {
        width: parent.width
        height: parent.height
        // Align the paws of the sleeping photo with the physics anchor.
        y: sprite.catSleeping ? sprite.pose[0] - (height - paintedHeight) : 0
        visible: sprite.kind === "cat"
        source: visible ? (sprite.catSleeping ? "assets/cat-sleep.png" : "assets/cat.png") : ""
        fillMode: Image.PreserveAspectFit
        mirror: sprite.mirrored
        verticalAlignment: Image.AlignBottom
        mipmap: true
    }
    Item {
        id: cell
        // Clip one cell, then move the atlas underneath it.
        visible: sprite.kind !== "cat"
        clip: true
        width: sprite.robot ? 57.6 : 110
        height: sprite.robot ? 62.4 : 74
        x: sprite.robot ? (parent.width - width) / 2 : sprite.mirrored ? parent.width + 30 - width : -30
        // Reflect the clipped cell. Mirroring the atlas would also reverse frame order.
        transform: Scale { origin.x: cell.width / 2; xScale: sprite.mirrored ? -1 : 1 }
        y: sprite.pose[0]
        Image {
            readonly property int cols: sprite.robot ? 8 : Math.min(8, sprite.timing.length)
            source: sprite.kind === "cat" ? "" : sprite.robot ? "assets/codex.webp" : "assets/clawd-" + sprite.clipName + ".png"
            width: parent.width * cols
            height: parent.height * (sprite.robot ? 9 : Math.ceil(sprite.timing.length / 8))
            x: -parent.width * (sprite.frame % cols)
            y: -parent.height * (sprite.robot ? sprite.row : Math.floor(sprite.frame / 8))
            smooth: sprite.robot
            mipmap: sprite.robot
            fillMode: Image.Stretch
        }
    }
}
