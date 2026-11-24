import Quickshell

Region {
    id: outline
    required property var pet

    component Slice: Region {
        required property int index
        readonly property var part: outline.pet.body.parts[index]
        x: Math.floor(outline.pet.x + part.l)
        y: Math.floor(outline.pet.y + part.t)
        width: outline.pet.visible ? Math.ceil(outline.pet.x + part.r) - x : 0
        height: Math.ceil(outline.pet.y + part.b) - y
    }

    Slice { index: 0 }
    Slice { index: 1 }
    Slice { index: 2 }
    Slice { index: 3 }
    Slice { index: 4 }
    Slice { index: 5 }
    Slice { index: 6 }
}
