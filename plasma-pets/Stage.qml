import QtQuick
import "Physics.js" as Physics

Item {
    id: stage
    property alias cat: cat
    property alias clawd: clawd
    property alias codex: codex
    readonly property var pets: [cat, clawd, codex]
    property var menuPet: null
    readonly property bool menuOpen: menuPet !== null
    property point menuPoint
    property bool placed: false
    property bool dropOnStart: false
    signal empty()

    function clamp(value, low, high) {
        return Math.max(low, Math.min(Math.max(low, high), value))
    }
    function layout() {
        if (width < 100 || height < 80) return
        if (!placed) {
            let left = (width - 185) / 2
            for (let i = 0; i < pets.length; i++) {
                pets[i].x = clamp(left + i * 68, 0, width - pets[i].width)
                const pet = pets[i]
                pet.y = dropOnStart ? -pet.body.t + i * 25 : pet.floorY
                if (dropOnStart) pet.launch(0, 0)
            }
            placed = true
        } else {
            for (const p of pets) {
                p.x = clamp(p.x,-p.body.l,width-p.body.r)
                p.y = clamp(p.y,-p.body.t,p.floorY)
                if (!p.inAir && !p.held && !p.riding) p.y = p.floorY
            }
        }
    }
    Component.onCompleted: Qt.callLater(layout)
    onWidthChanged: Qt.callLater(layout)
    onHeightChanged: Qt.callLater(layout)

    function menuFor(p, point) {
        menuPoint = point
        menuPet = p
        p.rest()
        context.selected = 0
        context.forceActiveFocus()
    }
    function summon(caller, friend) {
        const side = caller.x + caller.width + friend.width + 12 < width ? 1 : -1
        const target = clamp(side > 0 ? caller.x + caller.width + 8 : caller.x - friend.width - 8, 0, width - friend.width)
        if (!friend.visible) {
            Physics.place(friend, pets, clamp(target + 100 * side, 0, width - friend.width), width, height)
            friend.visible = true
        }
        friend.held = false
        if (friend.inAir) { friend.vx = 0; friend.vy = 0 }
        friend.sleeping = false
        friend.walkTo(target)
        caller.react("wave", "привет, " + friend.petName + "!", 2300)
        friend.say(friend.kind === "cat" ? "мяу!" : "уже иду!")
    }
    function movePet(p, dx, dy) {
        return Physics.move(p, pets, dx, dy, stage)
    }
    function landed(p, other, impact) {
        if (!other || impact < 240) return
        other.sleeping = false
        if (other.gesture === "squash") return
        other.react("squash", other.kind === "codex" ? "всё упало" : "", 940)
        other.spark("✦", "#ffdf70")
        p.spark("✦", "#ffd471")
    }
    function updateStack(p) {
        const base = p.riding
        if (!base || p.held || !p.visible) return
        const dist = base.visible ? Physics.gap(p,base,false,1) : Infinity
        if (!isFinite(dist)) { p.launch(p.slip * 64,0); return }
        p.y += dist
        // Only the actual contact patch can balance the passenger.
        let left = Infinity, right = -Infinity
        for (const a of p.body.parts) for (const b of base.body.parts) {
            if (Math.abs(p.y+a.b-base.y-b.t) > 2.5) continue
            const l = Math.max(p.x+a.l,base.x+b.l), r = Math.min(p.x+a.r,base.x+b.r)
            if (r > l) { left = Math.min(left,l); right = Math.max(right,r) }
        }
        const center = p.x + (p.body.l+p.body.r)/2
        p.slip = center < left-4 ? -1 : center > right+4 ? 1 : 0
    }
    function reconcile() {
        if (!placed) return
        const active = pets.filter(p => p.visible)
        for (const p of active) {
            p.x = clamp(p.x,-p.body.l,width-p.body.r)
            if (!p.riding && !p.inAir && !p.held) p.y = p.floorY
            p.y = clamp(p.y,-p.body.t,p.floorY)
        }
        // Align the bottom of a stack first, then its passengers.
        for (let pass=0; pass<2; pass++) {
            for (const p of active) updateStack(p)
        }
        // A freshly drawn pose can grow into a neighbour between two sweeps.
        for (let i=0; i<active.length; i++) for (let j=i+1; j<active.length; j++) {
            const a=active[i], b=active[j]
            if (a.riding === b || b.riding === a) continue
            const dir = a.x+a.width/2 < b.x+b.width/2 ? 1 : -1
            const side = Physics.gap(a,b,true,dir)
            if (side >= -0.05 || Physics.gap(a,b,true,-dir) >= 0) continue
            const upper = a.y+a.body.b < b.y+b.body.b ? a : b
            const lower = upper === a ? b : a
            const vertical = Physics.gap(upper,lower,false,1)
            if (vertical >= -0.05 || Physics.gap(lower,upper,false,1) >= 0) continue
            if (vertical > side && (upper.inAir || upper.held || upper.riding)) {
                upper.y += vertical
            } else {
                const share = a.held ? 0 : b.held ? 1 : 0.5
                const oldX = a.x
                a.x = clamp(a.x+dir*side*share,-a.body.l,width-a.body.r)
                const oldB = b.x
                b.x = clamp(b.x-dir*side+(a.x-oldX),-b.body.l,width-b.body.r)
                a.x = clamp(oldX+dir*side+(b.x-oldB),-a.body.l,width-a.body.r)
            }
        }
    }
    Timer {
        running: stage.placed && stage.pets.some(p => p.visible && p.riding !== null)
        repeat: true
        interval: 16
        onTriggered: {
            for (const p of stage.pets) {
                if (p.riding && p.slip) stage.movePet(p,p.slip*1.35,0)
            }
            stage.reconcile()
        }
    }
    Pet { id: cat; arena: stage; kind: "cat"; petName: "Тилкайо" }
    Pet { id: clawd; arena: stage; kind: "clawd"; petName: "Clawd" }
    Pet { id: codex; arena: stage; kind: "codex"; petName: "Codex" }

    MouseArea {
        z: 40
        anchors.fill: parent
        visible: stage.menuOpen
        acceptedButtons: Qt.AllButtons
        onPressed: stage.menuPet = null
    }
    Rectangle {
        id: context
        objectName: "petContextMenu"
        // Keep the click as an anchor even while the delegates acquire their sizes.
        x: stage.clamp(stage.menuPoint.x + width + 4 <= stage.width
                       ? stage.menuPoint.x + 2 : stage.menuPoint.x - width - 2, 2, stage.width - width - 2)
        y: stage.clamp(stage.menuPoint.y + height + 4 <= stage.height
                       ? stage.menuPoint.y + 2 : stage.menuPoint.y - height - 2, 2, stage.height - height - 2)
        z: 41
        visible: stage.menuOpen
        width: Math.min(182, stage.width - 8)
        height: entries.height + 10
        radius: 10
        color: "#20241f"
        border.color: "#414640"
        property int selected: 0
        readonly property var options: {
            const p = stage.menuPet
            if (!p) return []
            let rows = [
                ["♡", "Погладить", "pet"], ["♫", "Потанцевать", "dance"], ["☀", "Помахать", "wave"],
                ["☾", p.sleeping ? "Разбудить" : "Уложить спать", "sleep"], ["↑", "Подкинуть", "throw"]
            ]
            if (p === clawd) rows.push(["◉","Поиграть с мячом","ball"],["♫","Сыграть на трубе","trumpet"],["⚲","Достать лупу","detective"])
            for (const friend of [codex, clawd, cat])
                if (p !== friend) rows.push(["↗", "Позвать " + ({cat:"Тилкайо",codex:"Кодекса",clawd:"Clawd"})[friend.kind], friend])
            rows.push(["×", "Убрать", "hide"])
            return rows
        }
        function choose(i) {
            const p = stage.menuPet
            if (!p || !options[i]) return
            const action = options[i][2]
            stage.menuPet = null
            if (typeof action === "string") p.perform(action)
            else stage.summon(p, action)
        }
        Keys.onEscapePressed: stage.menuPet = null
        Keys.onDownPressed: selected = (selected + 1) % options.length
        Keys.onUpPressed: selected = (selected + options.length - 1) % options.length
        Keys.onReturnPressed: choose(selected)
        Column {
            id: entries
            x: 5; y: 5
            width: parent.width - 10
            Repeater {
                model: context.options
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: entries.width
                    height: Math.min(30, Math.max(14, (stage.height - 18) / Math.max(1, context.options.length)))
                    radius: 5
                    color: context.selected === index ? "#363b34" : "transparent"
                    Text { x: 8; anchors.verticalCenter: parent.verticalCenter; color: "#d8dcd5"; text: modelData[0]; font.pixelSize: 15 }
                    Text { x: 33; anchors.verticalCenter: parent.verticalCenter; color: "#f1f1eb"; text: modelData[1]; font.pixelSize: 13 }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: context.selected = index
                        onClicked: context.choose(index)
                    }
                }
            }
        }
    }
}
