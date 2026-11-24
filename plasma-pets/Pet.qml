import QtQuick
import "Physics.js" as Physics
import "Frames.js" as Frames

Item {
    id: pet
    required property Item arena
    required property string kind
    required property string petName
    width: kind === "cat" ? 57 : kind === "clawd" ? 48 : 46
    height: kind === "cat" ? 56 : kind === "clawd" ? 32 : 52
    z: held ? 20 : inAir ? 10 : kind === "cat" ? 3 : 2
    readonly property var body: Physics.hull(art.pose, width, height, art.mirrored,
                                             stretch.xScale, stretch.yScale,
                                             carrySwing.running ? carrySwing.angle : art.rotation,
                                             carrySwing.running ? dragArea.grab.x : width / 2,
                                             carrySwing.running ? dragArea.grab.y : height)
    readonly property real floorY: arena.height - body.b
    property Item riding: null
    property int slip: 0
    property bool vaulting: false
    property int nextScene: 0
    onBodyChanged: if (arena && arena.placed) Qt.callLater(arena.reconcile)

    property bool sleeping: false
    property bool held: false
    property bool dragged: false
    property bool inAir: false
    property bool walking: false
    property int facing: 1
    property real vx: 0
    property real vy: 0
    property real destination: 0
    property real walkSpeed: 30
    property string gesture: ""
    property string speech: ""
    readonly property string activity: held ? "held" : inAir ? "air" : sleeping ? "sleep" : gesture || (walking ? "walk" : "idle")
    readonly property bool busy: !visible || held || inAir || sleeping || walking || gesture !== "" || arena.menuPet === pet

    function say(words) {
        speech = words
        bubbleTimer.restart()
    }
    function spark(symbol, tint) {
        const effect = mote.createObject(arena, {
            x: x + width * (0.32 + Math.random() * 0.36), y: y - 8,
            text: symbol, color: tint, drift: (Math.random() - 0.5) * 30
        })
        if (effect) effect.start()
    }
    function rest() {
        walking = false
        vaulting = false
        gesture = ""
        gestureTimer.stop()
    }
    function react(action, words, ms) {
        rest()
        gesture = action
        if (words) say(words)
        gestureTimer.interval = ms
        gestureTimer.restart()
    }
    function walkTo(target) {
        rest()
        destination = arena.clamp(target, -body.l, arena.width - body.r)
        facing = destination >= x ? 1 : -1
        walkSpeed = 24 + Math.random() * 14
        walking = Math.abs(destination - x) > 1
    }
    function launch(dx, dy) {
        rest()
        sleeping = false
        riding = null
        slip = 0
        inAir = true
        vx = dx
        vy = dy
    }
    function vault(other) {
        const dir = facing
        const far = dir > 0 ? other.x + other.body.r - body.l + 9 : other.x + other.body.l - body.r - 9
        const target = arena.clamp(dir > 0 ? Math.max(destination,far) : Math.min(destination,far),-body.l,arena.width-body.r)
        const obstacleHeight = Math.max(20,y+body.b-other.y-other.body.t)
        const speedY = Math.sqrt(2*1330*(obstacleHeight+36))
        const clearTime = Math.sqrt(2*36/1330)
        const span = body.r-body.l+other.body.r-other.body.l+12
        launch(dir*Math.max(135,span/(2*clearTime)), -speedY)
        vaulting = true
        destination = target
    }
    function perform(action) {
        if (action === "sleep") {
            rest()
            sleeping = !sleeping
            if (sleeping) { speech = ""; spark("z", "#e8f0ff") }
            else react("wave", kind === "cat" ? "мрр?" : "я тут!", 1200)
            return
        }
        sleeping = false
        switch (action) {
        case "pet":
            react("pet", kind === "cat" ? "мур-мур" : "", 1550)
            spark("♥", "#fa88a4")
            echo.restart()
            break
        case "ball": case "trumpet": case "detective":
            react(action, "", Frames.clawd[action].reduce((sum, ms) => sum + ms, 0))
            break
        case "dance":
            react("dance", "", 3800)
            spark("♫", "#ffcf72")
            break
        case "wave":
            react("wave", kind === "cat" ? "мяу!" : "привет!", 1800)
            break
        case "throw":
            launch(facing * 112, -Math.min(740, Math.sqrt(2 * 1330 * arena.height * 0.6)))
            break
        case "hide":
            rest()
            visible = false
            if (!arena.pets.some(p => p.visible)) arena.empty()
            break
        }
    }
    function wander() {
        if (busy || !arena.placed || arena.menuOpen) return
        const r = Math.random()
        if (r < 0.43) {
            walkTo(x + (Math.random() < 0.5 ? -1 : 1) * (32 + 88 * Math.random()))
        } else if (r < 0.79 && kind === "clawd") {
            const scenes = ["ball","trumpet","detective","dance"]
            perform(scenes[nextScene])
            nextScene = (nextScene+1) % scenes.length
        } else if (r < 0.67 && kind === "codex") {
            react("work", "> npm run build", 2900)
        } else if (r < 0.75 && kind === "cat") {
            react("doze", "", 2400)
            spark("z", "#e8f0ff")
        } else if (r < 0.85) {
            const friend = arena.pets.find(p => p !== pet && p.visible && !p.held && !p.inAir && Math.abs(p.x - x) < 108)
            if (friend) {
                react("wave", kind === "cat" ? "мрр" : "привет, " + friend.petName + "!", 1750)
                if (!friend.busy) friend.spark(friend.kind === "cat" ? "♥" : "?", "#ffd987")
            }
        }
    }

    Timer {
        running: pet.visible
        repeat: true
        interval: 4200 + Math.floor(Math.random() * 4000)
        onTriggered: { pet.wander(); interval = 3900 + Math.floor(Math.random() * 5200) }
    }
    Timer {
        id: gestureTimer
        onTriggered: {
            if (pet.gesture === "squash") {
                if (pet.arena.pets.some(p => p.visible && p.riding === pet)) {
                    interval = 80; restart(); return
                }
                pet.react("dizzy","",pet.kind === "clawd" ? Frames.clawd.dizzy.reduce((a,b) => a+b,0) : 900)
                pet.spark("✦","#ffe681")
            } else pet.gesture = ""
        }
    }
    Timer { id: bubbleTimer; interval: 2050; onTriggered: pet.speech = "" }
    Timer { id: echo; interval: 180; onTriggered: pet.spark("♥", "#ffadbf") }
    Timer {
        interval: 1050; repeat: true
        running: pet.visible && (pet.sleeping || pet.activity === "doze" || pet.activity === "dance")
        onTriggered: pet.activity === "dance" ? pet.spark("♪", "#ffcf72") : pet.spark("z", "#e8f0ff")
    }
    Timer {
        id: motion
        interval: 16
        running: pet.visible && !pet.held && (pet.inAir || pet.walking)
        repeat: true
        property double last: 0
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now()
            const dt = Math.min(0.04, Math.max(0.001, (now - last) / 1000))
            last = now
            if (pet.inAir) {
                pet.vy += 1330 * dt
                const hit = pet.arena.movePet(pet, pet.vx * dt, pet.vy * dt)
                if (hit.hitX && (!pet.vaulting || !hit.side)) pet.vx *= -0.48
                if (hit.hitY) {
                    const impact = pet.vy
                    if (impact < 0) {
                        pet.vy = Math.abs(impact) * 0.35
                    } else {
                        if (!pet.vaulting) pet.arena.landed(pet, hit.other, impact)
                        if (!pet.vaulting && !hit.other && impact > 205) {
                            pet.vy = -impact * 0.22
                            pet.vx *= 0.48
                        } else {
                            pet.inAir = false
                            pet.riding = hit.other
                            if (pet.vaulting) {
                                const goal = pet.destination
                                pet.walkTo(goal)
                            }
                            pet.arena.reconcile()
                            pet.vx = 0
                            pet.vy = 0
                        }
                    }
                }
            } else {
                const delta = pet.destination - pet.x
                const stride = pet.walkSpeed * dt
                const hit = pet.arena.movePet(pet, Math.sign(delta) * Math.min(stride, Math.abs(delta)), 0)
                if (hit.side) pet.vault(hit.side)
                else if (hit.hitX || Math.abs(delta) <= stride) pet.walking = false
            }
        }
    }

    Timer {
        id: carrySwing
        interval: 16
        repeat: true
        property real angle: 0
        property real angularVelocity: 0
        property double lastTick: 0

        function clear() {
            stop()
            angle = 0
            angularVelocity = 0
        }

        onRunningChanged: if (running) lastTick = Date.now()
        onTriggered: {
            if (!pet.visible) {
                clear()
                return
            }
            const now = Date.now()
            const elapsed = Math.min(0.048, Math.max(0.001, (now - lastTick) / 1000))
            lastTick = now

            // Drive the tilt from recent drag samples. Once the pointer stops
            // sending events, the spring still moves and swings back past center.
            const idleTime = now - dragArea.sampledAt
            const target = pet.held
                    ? pet.arena.clamp(pet.vx / 30, -24, 24) * Math.exp(-Math.max(0, idleTime - 30) / 34)
                    : 0
            const steps = Math.ceil(elapsed / 0.008)
            const dt = elapsed / steps
            let nextAngle = angle
            let speed = angularVelocity
            for (let i = 0; i < steps; i++) {
                speed += (190 * (target - nextAngle) - 9 * speed) * dt
                nextAngle += speed * dt
            }
            if (Math.abs(target) < 0.1 && Math.abs(nextAngle) < 0.2 && Math.abs(speed) < 2) {
                clear()
                return
            }
            angle = nextAngle
            angularVelocity = speed
        }
    }

    Item {
        anchors.fill: parent
        transform: Rotation {
            origin.x: dragArea.grab.x
            origin.y: dragArea.grab.y
            angle: carrySwing.angle
        }
        PetArtwork {
            id: art
            anchors.fill: parent
            kind: pet.kind
            facing: pet.facing
            activity: pet.activity
            transformOrigin: Item.Bottom
            property real inhale: 0
            SequentialAnimation on inhale {
                running: art.catSleeping && pet.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 0.045; duration: 920; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.045; to: 0; duration: 1300; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 200 }
            }
            property real sway: 0
            rotation: carrySwing.running ? 0 : sway
            SequentialAnimation on sway {
                running: pet.visible && ((pet.activity === "dance" && pet.kind !== "clawd") || (pet.kind === "cat" && ["walk","wave","pet"].includes(pet.activity)))
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: -5; duration: 155; easing.type: Easing.InOutSine }
                NumberAnimation { to: 5; duration: 220; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 145; easing.type: Easing.InOutSine }
            }
            transform: Scale {
                id: stretch
                origin.x: pet.width / 2
                origin.y: pet.height
                xScale: pet.activity === "squash" ? 1.32 : 1
                property real baseHeight: pet.activity === "squash" ? 0.21 : pet.sleeping || art.catSleeping ? 0.94 : 1
                yScale: baseHeight + (art.catSleeping ? art.inhale : 0)
                Behavior on baseHeight {
                    NumberAnimation { duration: pet.gesture === "dizzy" ? 180 : 75; easing.type: pet.gesture === "dizzy" ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 2.8 }
                }
                Behavior on xScale { NumberAnimation { duration: 110 } }
            }
        }
    }
    Rectangle {
        visible: pet.speech.length > 0
        width: label.implicitWidth + 14
        height: label.implicitHeight + 7
        radius: height / 2
        color: "#ec21251f"
        x: pet.arena.clamp(pet.x + (pet.width - width) / 2, 2, pet.arena.width - width - 2) - pet.x
        y: pet.y > height + 8 ? -height - 5 : pet.height + 4
        Text {
            id: label
            anchors.centerIn: parent
            color: "#f5f5ed"
            font.pixelSize: 11
            text: pet.speech
        }
    }
    Component {
        id: mote
        Text {
            id: glyph
            z: 25
            required property real drift
            font.bold: true
            font.pixelSize: 12
            function start() { flight.start() }
            ParallelAnimation {
                id: flight
                NumberAnimation { target: glyph; property: "x"; to: glyph.x + glyph.drift; duration: 820 }
                NumberAnimation { target: glyph; property: "y"; to: glyph.y - 32; duration: 820 ; easing.type: Easing.OutQuad }
                SequentialAnimation {
                    PauseAnimation { duration: 270 }
                    NumberAnimation { target: glyph; property: "opacity"; to: 0; duration: 550 }
                }
                onFinished: glyph.destroy()
            }
        }
    }

    MouseArea {
        id: dragArea
        x: pet.body.l
        y: pet.body.t
        width: pet.body.r-pet.body.l
        height: pet.body.b-pet.body.t
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: pet.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point grab
        property point previous
        property point startPoint
        property bool wokeOnFloor: false
        property double sampledAt
        property double lastSpark
        onPressed: mouse => {
            const point = mapToItem(pet.arena, mouse.x, mouse.y)
            if (mouse.button === Qt.RightButton) {
                pet.arena.menuFor(pet, point)
                return
            }
            carrySwing.clear()
            wokeOnFloor = art.catSleeping && !pet.riding && !pet.inAir
            pet.rest()
            pet.riding = null
            pet.held = true
            pet.dragged = false
            pet.inAir = false
            pet.vx = 0
            pet.vy = 0
            grab = Qt.point(point.x-pet.x, point.y-pet.y)
            previous = startPoint = point
            sampledAt = Date.now()
        }
        onPositionChanged: mouse => {
            if (!pet.held) return
            const point = mapToItem(pet.arena, mouse.x, mouse.y)
            if (!pet.dragged && Math.hypot(point.x - startPoint.x, point.y - startPoint.y) < 4) return
            pet.dragged = true
            pet.sleeping = false
            const now = Date.now()
            const dt = Math.max(0.009, (now - sampledAt) / 1000)
            const dx = point.x - previous.x
            const dy = point.y - previous.y
            if (Math.abs(dx) + Math.abs(dy) < 0.1) return
            pet.vx = pet.arena.clamp(0.35 * pet.vx + 0.65 * dx / dt, -900, 900)
            pet.vy = pet.arena.clamp(0.35 * pet.vy + 0.65 * dy / dt, -850, 850)
            if (Math.abs(dx) > 3) pet.facing = dx > 0 ? 1 : -1
            const hit = pet.arena.movePet(pet, point.x - grab.x - pet.x, point.y - grab.y - pet.y)
            if (hit.hitY && hit.other && pet.vy > 240 && hit.other.gesture !== "squash")
                pet.arena.landed(pet, hit.other, pet.vy)
            if (now - lastSpark > 230) { pet.spark("✦", "#ffce71"); lastSpark = now }
            previous = point
            sampledAt = now
            if (!carrySwing.running) carrySwing.start()
        }
        onReleased: mouse => {
            if (mouse.button !== Qt.LeftButton || !pet.held) return
            pet.held = false
            if (pet.dragged) {
                const decay = Math.max(0, 1 - (Date.now() - sampledAt) / 120)
                pet.launch(pet.vx * decay, pet.vy * decay)
            } else {
                pet.perform("pet")
                if (wokeOnFloor) pet.y = pet.floorY
                else if (pet.y < pet.floorY) pet.launch(0, 0)
            }
        }
        onCanceled: {
            if (pet.held) { pet.held = false; pet.launch(0, 0) }
        }
    }
}
