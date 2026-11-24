import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    Process {
        command: ["python3", Quickshell.shellDir + "/tray.py"]
        running: true
        onExited: (code, status) => {
            if (code === 0 && status === 0) Qt.quit()
        }
    }


    PanelWindow {
        id: overlay
        anchors { top: true; bottom: true; left: true; right: true }
        screen: Quickshell.screens.find(s => s.name === Quickshell.env("DESKTOP_PETS_OUTPUT")) ?? Quickshell.screens[0]
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "plasma-pets"
        WlrLayershell.keyboardFocus: stage.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region {
            // An open context menu takes one outside click to dismiss.
            width: stage.menuOpen ? stage.width : 0
            height: stage.menuOpen ? stage.height : 0
            PetRegion { pet: stage.cat }
            PetRegion { pet: stage.clawd }
            PetRegion { pet: stage.codex }
        }
        Stage {
            id: stage
            dropOnStart: true
            anchors.fill: parent
            onEmpty: Qt.quit()
        }
    }
}
