import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
    id: launcher

    required property var config
    property var gamesData: []
    property var filteredGames: []
    property var colors: ({})
    property int selectedIndex: 0
    property string searchText: ""
    property string selectedSource: "all"

    // Config values
    property string orientation: config?.display?.orientation ?? "horizontal"
    property int gridColumns: config?.display?.grid_size?.[0] ?? 4
    property int gridRows: config?.display?.grid_size?.[1] ?? 3
    property int itemWidth: config?.display?.item_width ?? 200
    property int itemHeight: config?.display?.item_height ?? 300
    property int spacing: config?.display?.spacing ?? 20

    property int sidebarWidth: 68

    width: sidebarWidth + spacing + (itemWidth * gridColumns) + (spacing * (gridColumns + 1))
    height: (itemHeight * gridRows) + (spacing * (gridRows + 1)) + 60 + 44 + spacing

    focus: true
    activeFocusOnTab: true
    color: "transparent"
    radius: 16

    // Background with blur
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: colors.background || "#1a1a1a"
        opacity: config?.appearance?.background_opacity ?? 0.85
        layer.enabled: config?.appearance?.blur_background ?? true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.8
            blurMax: 32
        }
    }

    // Border
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: colors.color5 || '#73ff00'
        border.width: 2
        opacity: 0.5
    }

    Component.onCompleted: {
        launcher.forceActiveFocus()
        loadGames()
        gamepadService.running = true
    }

    // Available sources computed from data
    property var availableSources: {
        const seen = {}
        const out = []
        for (const g of gamesData) {
            const s = g.source || ""
            if (s && !seen[s]) { seen[s] = true; out.push(s) }
        }
        return out
    }

    function sourceInfo(src) {
        const map = {
            "steam":   { icon: "\uf1b6", font: "Font Awesome 7 Brands",    label: "Steam"   },
            "epic":    { icon: "\uf794", font: "Font Awesome 7 Free Solid", label: "Epic"    },
            "gog":     { icon: "\uf520", font: "Font Awesome 7 Free Solid", label: "GOG"     },
            "amazon":  { icon: "\uf270", font: "Font Awesome 7 Brands",     label: "Amazon"  },
            "heroic":  { icon: "\uf6d7", font: "Font Awesome 7 Free Solid", label: "Heroic"  },
            "manual":  { icon: "\uf11b", font: "Font Awesome 7 Free Solid", label: "Manual"  },
            "desktop": { icon: "\uf108", font: "Font Awesome 7 Free Solid", label: "Desktop" },
            "config":  { icon: "\uf135", font: "Font Awesome 7 Free Solid", label: "Config"  },
        }
        return map[src] || { icon: "\uf11b", font: "Font Awesome 7 Free Solid", label: src }
    }

    // Keyboard navigation
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (searchText !== "") {
                searchText = ""
                searchField.clear()
            } else {
                Qt.quit()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!searchField.activeFocus) launchSelectedGame()
            event.accepted = true
        } else if (event.key === Qt.Key_Left && !searchField.activeFocus) {
            navigateLeft(); event.accepted = true
        } else if (event.key === Qt.Key_Right && !searchField.activeFocus) {
            navigateRight(); event.accepted = true
        } else if (event.key === Qt.Key_Up && !searchField.activeFocus) {
            navigateUp(); event.accepted = true
        } else if (event.key === Qt.Key_Down && !searchField.activeFocus) {
            navigateDown(); event.accepted = true
        } else if (event.key === Qt.Key_Backspace && !searchField.activeFocus) {
            if (searchText.length > 0) {
                searchText = searchText.slice(0, -1)
                searchField.text = searchText
            }
            event.accepted = true
        } else if (event.text && event.text.length > 0 && !event.modifiers && !searchField.activeFocus) {
            searchText += event.text
            searchField.text = searchText
            searchField.forceActiveFocus()
            event.accepted = true
        }
    }

    Keys.onEscapePressed: Qt.quit()

    onSearchTextChanged:   filterGames()
    onSelectedSourceChanged: filterGames()

    signal closeRequested()

    Process {
        id: gamesProcess
        command: ["python3", Qt.resolvedUrl("service/backend.py").toString().replace("file://", "")]
        running: false
        property string output: ""
        stdout: SplitParser { onRead: data => gamesProcess.output += data }
        onExited: {
            try {
                const result = JSON.parse(gamesProcess.output)
                gamesData = result.games || []
                colors = result.colors || {}
                filterGames()
            } catch (e) {
                console.error("Failed to parse games data:", e)
            }
            gamesProcess.output = ""
        }
    }
    
    function loadGames() { gamesProcess.running = true }

    function filterGames() {
        let result = gamesData.slice()
        if (selectedSource !== "all")
            result = result.filter(g => (g.source || "") === selectedSource)
        if (searchText.trim() !== "") {
            const q = searchText.toLowerCase()
            result = result.filter(g =>
                (g.name || "").toLowerCase().includes(q) ||
                (g.category || "").toLowerCase().includes(q)
            )
        }
        filteredGames = result
        if (selectedIndex >= filteredGames.length)
            selectedIndex = Math.max(0, filteredGames.length - 1)
    }

    function navigateLeft() {
        if (orientation === "horizontal" && selectedIndex > 0) selectedIndex--
        else if (orientation === "vertical" && selectedIndex % gridColumns > 0) selectedIndex--
    }
    function navigateRight() {
        if (orientation === "horizontal" && selectedIndex < filteredGames.length - 1) selectedIndex++
        else if (orientation === "vertical" && selectedIndex % gridColumns < gridColumns - 1 && selectedIndex < filteredGames.length - 1) selectedIndex++
    }
    function navigateUp() {
        if (orientation === "vertical" && selectedIndex >= gridColumns) selectedIndex -= gridColumns
    }
    function navigateDown() {
        if (orientation === "vertical" && selectedIndex + gridColumns < filteredGames.length) selectedIndex += gridColumns
    }
    function launchSelectedGame() {
        if (filteredGames.length === 0) return
        launchGame(filteredGames[selectedIndex])
    }
    function navigateSource(direction) {
        var sources = ["all"].concat(availableSources)
        var current = sources.indexOf(selectedSource)
        if (direction === "up")
            current = (current - 1 + sources.length) % sources.length
        else
            current = (current + 1) % sources.length
        selectedSource = sources[current]
        selectedIndex = 0  // reset la sélection au changement de filtre
    }

    Process {
        id: launchProcess
        running: false
    }

    function launchGame(game, cardItem) {
        launchProcess.command = ["sh", "-c", "setsid " + game.exec + " &"]
        launchProcess.running = true
        launcher.enabled = false
        if (config?.behavior?.close_on_launch ?? true) {
            launchOverlay.colors = colors
            // Récupère la position de la carte dans le repère du launcher
            var pos = cardItem ? cardItem.mapToItem(launcher, 0, 0) : null
            launchOverlay.show(
                game.image || "",
                game.name || "",
                game.logo || "",
                pos ? pos.x : 0,
                pos ? pos.y : 0,
                cardItem ? cardItem.width : launcher.width,
                cardItem ? cardItem.height : launcher.height
            )
        }
    }

    Process {
    id: gamepadService
    command: ["/usr/bin/python3", Qt.resolvedUrl("service/gamepad.py").toString().replace("file://", "")]
    running: false   // ← false, on démarre dans onCompleted

    stdout: SplitParser {
        onRead: function(line) {
            try {
                var evt = JSON.parse(line)
                if (evt.type === "button") {
                    gamepadHandler.handle(evt.action)
                }
            } catch(e) {}
        }
    }
}
 
    // ── Handler des actions manette ────────────────────────────────────────────
    QtObject {
        id: gamepadHandler
    
        function handle(action) {
            switch(action) {
                case "left":
                    navigateLeft()
                    break
                case "right":
                    navigateRight()
                    break
                case "select":
                    launchSelectedGame()
                    break
                case "close":
                    launcher.closeRequested()
                    break
                case "toggle":
                    launcher.visible = !launcher.visible
                    break
                case "up":
                    navigateSource("up")
                    break
                case "down":
                    navigateSource("down")
                    break
            }
        }
    }
    // ═══════════════════════════════════════════════════════════════════════
    // LAYOUT PRINCIPAL
    // ═══════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        anchors.margins: spacing

        // ── SIDEBAR GAUCHE ───────────────────────────────────────────────────
        Rectangle {
            id: sidebar
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: sidebarWidth - spacing
            radius: 12
            color: "transparent"
            border.color: "transparent"
            border.width: 1

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 0
                spacing: 4

                // Bouton ALL
                Rectangle {
                    width: parent.width
                    height: width
                    radius: 22
                    color: selectedSource === "all"
                        ? Qt.rgba(
                            parseInt((colors.color5||"#73ff00").slice(1,3),16)/255,
                            parseInt((colors.color5||"#73ff00").slice(3,5),16)/255,
                            parseInt((colors.color5||"#73ff00").slice(5,7),16)/255,
                            0.22)
                        : (allMouse.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent")
                    border.color: selectedSource === "all" ? (colors.color5 || "#73ff00") : "transparent"
                    border.width: 2
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "⊞"
                            font.pixelSize: 20
                            color: selectedSource === "all" ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                            opacity: selectedSource === "all" ? 1.0 : 0.45
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All"
                            font.pixelSize: 9
                            font.bold: selectedSource === "all"
                            font.family: "Open Sans Regular"
                            color: selectedSource === "all" ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                            opacity: selectedSource === "all" ? 1.0 : 0.4
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    Rectangle {
                        visible: selectedSource === "all"
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.topMargin: -3; anchors.rightMargin: -3
                        width: 18; height: 18; radius: 9
                        color: colors.color5 || "#73ff00"
                        Text { anchors.centerIn: parent; text: gamesData.length; font.pixelSize: 8; font.bold: true; color: "#1a1a1a" }
                    }

                    MouseArea {
                        id: allMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { launcher.selectedSource = "all"; launcher.forceActiveFocus() }
                    }
                }

                // Séparateur
                Rectangle {
                    width: parent.width * 0.6
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                // Boutons par source
                Repeater {
                    model: availableSources

                    Rectangle {
                        property string src: modelData
                        property bool active: launcher.selectedSource === src
                        property int count: gamesData.filter(g => g.source === src).length
                        property var info: launcher.sourceInfo(src)

                        width: parent.width
                        height: width
                        radius: 22
                        color: active
                            ? Qt.rgba(
                                parseInt((colors.color5||"#73ff00").slice(1,3),16)/255,
                                parseInt((colors.color5||"#73ff00").slice(3,5),16)/255,
                                parseInt((colors.color5||"#73ff00").slice(5,7),16)/255,
                                0.22)
                            : (srcMouse.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent")
                        border.color: active ? (colors.color5||"#73ff00") : "transparent"
                        border.width: 2
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: info.icon
                                font.family: info.font
                                font.pixelSize: 20
                                color: active ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                                opacity: active ? 1.0 : 0.45
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: info.label
                                font.pixelSize: 9
                                font.bold: active
                                font.family: "Open Sans Regular"
                                color: active ? (colors.color5||"#73ff00") : (colors.foreground||"#ffffff")
                                opacity: active ? 1.0 : 0.4
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        // Badge count actif
                        Rectangle {
                            visible: active
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: -3; anchors.rightMargin: -3
                            width: 18; height: 18; radius: 9
                            color: colors.color5 || "#73ff00"
                            Text { anchors.centerIn: parent; text: count; font.pixelSize: 8; font.bold: true; color: "#1a1a1a" }
                        }

                        // Tooltip au survol
                        Rectangle {
                            visible: srcMouse.containsMouse && !active
                            anchors.left: parent.right; anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: tipTxt.width + 16; height: 26; radius: 8
                            color: "#1a1a1a"
                            border.color: Qt.rgba(1,1,1,0.2); border.width: 1
                            z: 999
                            Text {
                                id: tipTxt
                                anchors.centerIn: parent
                                text: info.label + " (" + count + ")"
                                font.pixelSize: 11; font.family: "Open Sans Regular"; color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: srcMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { launcher.selectedSource = src; launcher.forceActiveFocus() }
                        }
                    }
                }
            }
        }
        // ── FIN SIDEBAR ──────────────────────────────────────────────────────

        // ── ZONE CONTENU PRINCIPALE ──────────────────────────────────────────
        Item {
            id: mainContent
            anchors.left: sidebar.right
            anchors.leftMargin: spacing
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // Barre de recherche
            Rectangle {
                id: searchBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                radius: 22
                color: Qt.rgba(
                    parseInt((colors.background||"#1a1a1a").slice(1,3),16)/255,
                    parseInt((colors.background||"#1a1a1a").slice(3,5),16)/255,
                    parseInt((colors.background||"#1a1a1a").slice(5,7),16)/255,
                    0.6)
                border.color: searchField.activeFocus ? (colors.color5||"#73ff00") : Qt.rgba(1,1,1,0.15)
                border.width: searchField.activeFocus ? 2 : 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    font.family: "Font Awesome 7 Free Solid"
                    font.pixelSize: 15
                    color: colors.foreground || "#ffffff"
                    opacity: 0.5
                }

                TextField {
                    id: searchField
                    anchors.left: parent.left; anchors.leftMargin: 38
                    anchors.right: clearBtn.left; anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 4
                    placeholderText: "Search for a game…"
                    placeholderTextColor: Qt.rgba(1,1,1,0.3)
                    color: colors.foreground || "#ffffff"
                    font.pixelSize: 14
                    font.family: "Open Sans Regular"
                    background: Item {}
                    Keys.onEscapePressed: { launcher.searchText = ""; searchField.clear(); launcher.forceActiveFocus() }
                    Keys.onReturnPressed:  { launcher.launchSelectedGame() }
                    Keys.onUpPressed:      { launcher.navigateUp();    launcher.forceActiveFocus() }
                    Keys.onDownPressed:    { launcher.navigateDown();  launcher.forceActiveFocus() }
                    Keys.onLeftPressed:    { launcher.navigateLeft();  launcher.forceActiveFocus() }
                    Keys.onRightPressed:   { launcher.navigateRight(); launcher.forceActiveFocus() }
                    onTextChanged: launcher.searchText = text
                }

                Rectangle {
                    id: clearBtn
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13
                    visible: launcher.searchText !== ""
                    color: clearMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: colors.foreground||"#ffffff"; opacity: 0.7 }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { launcher.searchText = ""; searchField.clear(); launcher.forceActiveFocus() }
                    }
                }
            }

            // Layout HORIZONTAL
            ColumnLayout {
                visible: launcher.orientation === "horizontal"
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: searchBar.bottom; anchors.bottom: parent.bottom
                anchors.topMargin: spacing
                spacing: spacing

                ListView {
                    id: gamesCarouselH
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: launcher.spacing
                    clip: true
                    model: filteredGames
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 300
                    preferredHighlightBegin: width / 2 - itemWidth / 2
                    preferredHighlightEnd: width / 2 + itemWidth / 2
                    currentIndex: selectedIndex
                    onCurrentIndexChanged: selectedIndex = currentIndex

                    MouseArea {
                        anchors.fill: parent; propagateComposedEvents: true; focus: false
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0) navigateLeft()
                            else navigateRight()
                            launcher.forceActiveFocus(); wheel.accepted = true
                        }
                        onClicked: (mouse) => { launcher.forceActiveFocus(); mouse.accepted = false }
                    }

                    delegate: GameCard {
                        width: itemWidth; height: itemHeight
                        gameName: modelData.name || "Unknown"
                        gameImage: modelData.image || ""
                        gameCategory: modelData.category || ""
                        gameSource: modelData.source || ""
                        isFavorite: modelData.favorite || false
                        isSelected: index === selectedIndex
                        gameColors: colors
                        lastPlayed: modelData.last_played || 0
                        scale: isSelected ? 1.0 : 0.85
                        opacity: isSelected ? 1.0 : 0.6
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        onClicked: { gamesCarouselH.currentIndex = index; launcher.forceActiveFocus() }
                        onLaunchRequested: { launchGame(modelData, this) }
                    }

                    Rectangle {
                        visible: filteredGames.length === 0
                        anchors.centerIn: parent; width: 300; height: 200; color: "transparent"
                        Column {
                            anchors.centerIn: parent; spacing: 16
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🎮"; font.pixelSize: 64; opacity: 0.3 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Aucun jeu trouvé"; font.pixelSize: 18; color: colors.foreground||"#ffffff"; opacity: 0.7 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: launcher.searchText !== "" ? "Essaie un autre terme" : "Aucun jeu dans cette source"; font.pixelSize: 14; color: colors.foreground||"#ffffff"; opacity: 0.5 }
                        }
                    }
                }

                // Indicateurs bas
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; color: "transparent"
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Repeater {
                            model: Math.min(filteredGames.length, 10)
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: colors.color5 || "#00ffff"
                                opacity: index === selectedIndex ? 1.0 : 0.3
                                scale: index === selectedIndex ? 1.3 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on scale { NumberAnimation { duration: 200 } }
                            }
                        }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: filteredGames.length > 0 ? (selectedIndex + 1) + " / " + filteredGames.length : "0"; font.pixelSize: 12; color: colors.foreground||"#ffffff"; opacity: 0.6 }
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "← → Navigate  ⏎ Launch  Esc Close"; font.pixelSize: 11; color: colors.foreground||'#15ff00'; opacity: 0.5 }
                }
            }

            // Layout VERTICAL
            RowLayout {
                visible: launcher.orientation === "vertical"
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: searchBar.bottom; anchors.bottom: parent.bottom
                anchors.topMargin: spacing
                spacing: spacing

                GridView {
                    id: gamesCarouselV
                    Layout.preferredWidth: (itemWidth * gridColumns) + (spacing * (gridColumns - 1))
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    cellWidth: itemWidth + spacing; cellHeight: itemHeight + spacing
                    clip: true; model: filteredGames
                    currentIndex: selectedIndex
                    onCurrentIndexChanged: selectedIndex = currentIndex

                    MouseArea {
                        anchors.fill: parent; propagateComposedEvents: true; focus: false
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0) navigateUp()
                            else navigateDown()
                            launcher.forceActiveFocus(); wheel.accepted = true
                        }
                        onClicked: (mouse) => { launcher.forceActiveFocus(); mouse.accepted = false }
                    }

                    delegate: GameCard {
                        width: itemWidth; height: itemHeight
                        gameName: modelData.name || "Unknown"
                        gameImage: modelData.image || ""
                        gameCategory: modelData.category || ""
                        gameSource: modelData.source || ""
                        isFavorite: modelData.favorite || false
                        isSelected: index === selectedIndex
                        gameColors: colors
                        lastPlayed: modelData.last_played || 0
                        scale: isSelected ? 1.0 : 0.85
                        opacity: isSelected ? 1.0 : 0.6
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        onClicked: { gamesCarouselV.currentIndex = index; launcher.forceActiveFocus() }
                        onLaunchRequested: { launchGame(modelData, this) }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true; Layout.preferredWidth: 50
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter; color: "transparent"
                    Column {
                        anchors.centerIn: parent; spacing: 12
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                            Repeater {
                                model: Math.min(filteredGames.length, 10)
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: colors.color5||"#00ffff"
                                    opacity: index === selectedIndex ? 1.0 : 0.3
                                    scale: index === selectedIndex ? 1.3 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                    Behavior on scale { NumberAnimation { duration: 200 } }
                                }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: filteredGames.length > 0 ? (selectedIndex+1)+"/"+filteredGames.length : "0"; font.pixelSize: 10; color: colors.foreground||"#ffffff"; opacity: 0.6 }
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "↑↓"; font.pixelSize: 10; color: colors.foreground||'#15ff00'; opacity: 0.5 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "⏎";  font.pixelSize: 10; color: colors.foreground||'#15ff00'; opacity: 0.5 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Esc"; font.pixelSize: 9;  color: colors.foreground||'#15ff00'; opacity: 0.5 }
                        }
                    }
                }
            }
        }
    }

    // Entrance animation
    ParallelAnimation {
        running: true
        NumberAnimation { target: launcher; property: "scale";   from: 0.8; to: 1.0; duration: config?.animations?.duration_ms ?? 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: launcher; property: "opacity"; from: 0;   to: 1.0; duration: config?.animations?.duration_ms ?? 300; easing.type: Easing.OutCubic }
    }
    LaunchOverlay {
        id: launchOverlay
        onDone: Qt.quit()
    }
}
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia

Rectangle {
    id: card

    property string gameName: "Game"
    property string gameImage: ""
    property string gameCategory: ""
    property string gameSource: ""  // steam, manual, config
    property bool isFavorite: false
    property bool isSelected: false
    property var gameColors: ({})
    property int lastPlayed: 0  // Unix timestamp
    property real glowStrength: 0.8
    property real glowBlur: 12
    property bool isWebM: gameImage.toLowerCase().endsWith(".webm")

    signal clicked()
    signal launchRequested()

    width: 220
    height: 300
    radius: 16

    color: gameColors.background || "#1a1a1a"
    border.color: isSelected ? (gameColors.color5 || "#00ffff") : "transparent"
    border.width: isSelected ? 3 : 0

    // Scale animation on selection
    scale: isSelected ? 1.05 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }

    // Glow + Shadow effect
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: isSelected ? (gameColors.color5 || "#00ffff") : "#80000000"
        shadowOpacity: isSelected ? 0.8 : 0.5
        shadowBlur: isSelected ? 1.0 : 0.4
        shadowVerticalOffset: isSelected ? 8 : 4
        shadowHorizontalOffset: 0
    }

    // Breathing animation when selected
    SequentialAnimation {
        running: isSelected
        loops: Animation.Infinite

        NumberAnimation {
            target: card.layer.effect
            from: isSelected ? 0.8 : 0.4
            to: isSelected ? 1.2 : 0.4
            duration: 1500
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: card.layer.effect
            from: isSelected ? 1.2 : 0.4
            to: isSelected ? 0.8 : 0.4
            duration: 1500
            easing.type: Easing.InOutSine
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        focus: false  // Don't steal focus from launcher

        onClicked: card.clicked()
        onDoubleClicked: card.launchRequested()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 0

        // Cover Image
        Rectangle {
            width: parent.width
            height: parent.height - 60
            radius: card.radius
            color: "#2a2a2a"
            clip: true

            // Image / WebP animé / WebM
            AnimatedImage {
                id: coverImage
                anchors.fill: parent
                anchors.margins: 2
                visible: !card.isWebM
                source: card.isWebM ? "" : gameImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                // N'anime que quand la carte est sélectionnée
                playing: isSelected
                paused: !isSelected

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: coverImage.width
                            height: coverImage.height
                            radius: card.radius
                        }
                    }
                }

                // Fallback for missing images
                Rectangle {
                    anchors.fill: parent
                    visible: !card.isWebM && (coverImage.status === Image.Error || coverImage.status === Image.Null)
                    color: gameColors.color8 || "#333333"

                    Text {
                        anchors.centerIn: parent
                        text: gameName.substring(0, 2).toUpperCase()
                        font.pixelSize: 48
                        font.bold: true
                        font.capitalization: Font.Capitalize
                        font.family: "Open Sans Regular"
                        color: gameColors.foreground || "#ffffff"
                        opacity: 0.5
                    }
                }
            }

            // Vidéo WebM animée
            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                anchors.margins: 2
                visible: card.isWebM
                layer.enabled: card.isWebM
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: videoOutput.width
                            height: videoOutput.height
                            radius: card.radius
                        }
                    }
                }
            }

            MediaPlayer {
                id: videoPlayer
                source: card.isWebM ? gameImage : ""
                videoOutput: videoOutput
                loops: MediaPlayer.Infinite
                autoPlay: card.isWebM
            }

            // Status badges (NOUVEAU/RÉCENT)
            Rectangle {
                id: statusBadge
                visible: lastPlayed === 0 || isRecent()
                height: 22
                width: badgeText.width + 12
                radius: 11
                color: lastPlayed === 0 ? "#ff3366" : "#33ff66"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 8
                opacity: 0.95

                function isRecent() {
                    if (lastPlayed === 0) return false
                    const now = Date.now() / 1000  // Convert to seconds
                    const daysSince = (now - lastPlayed) / 86400
                    return daysSince < 2  // Last 2 days
                }

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: lastPlayed === 0 ? "NEW" : "RECENT"
                    font.pixelSize: 9
                    font.capitalization: Font.Capitalize
                    font.family: "Open Sans Regular"
                    font.bold: true
                    color: "#1a1a1a"
                }

                // Pulse animation for NEW badge
                SequentialAnimation {
                    running: lastPlayed === 0
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: statusBadge
                        property: "scale"
                        from: 1.0
                        to: 1.1
                        duration: 800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: statusBadge
                        property: "scale"
                        from: 1.1
                        to: 1.0
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                }
            }

            // Favorite star
            Rectangle {
                visible: isFavorite
                width: 32
                height: 32
                radius: 16
                color: gameColors.color3 || "#ffaa00"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8

                Text {
                    anchors.centerIn: parent
                    text: "★"
                    font.pixelSize: 20
                    color: "#1a1a1a"
                }
            }

            // Platform badge (bottom-left)
            Rectangle {
                visible: gameSource !== ""
                height: 28
                width: 28
                radius: 14
                color: getPlatformColor()
                opacity: 0.95
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 8

                function getPlatformColor() {
                    if (gameSource === "steam") return gameColors.color8 || "#5A1E80"
                    if (gameSource === "epic") return gameColors.color10 || "#040000"
                    if (gameSource === "gog") return gameColors.color9 || "#7828AA"
                    if (gameSource === "amazon") return gameColors.color11 || "#92502D"
                    if (gameSource === "heroic") return gameColors.color13 || "#C8A46E"
                    if (gameSource === "config") return gameColors.color13 || "#C8A46E"
                    if (gameSource === "manual") return gameColors.color9 || "#7828AA"
                    return gameColors.color5 || "#967B53"
                }

                Text {
                    anchors.centerIn: parent
                    text: getPlatformIcon()
                    font.pixelSize: 14
                    font.family: getPlatformFont()
                    color: gameSource === "epic" ? "#ffffff" : (gameColors.background || '#ef2c2c2c')

                    function getPlatformFont() {
                        // Steam and Amazon use Brands font
                        if (gameSource === "steam" || gameSource === "amazon") {
                            return "Font Awesome 7 Brands"
                        }
                        return "Font Awesome 7 Free Solid"
                    }

                    function getPlatformIcon() {
                        if (gameSource === "steam") return "\uf1b6"     // fa-steam
                        if (gameSource === "epic") return "\uf794"      // fa-shopping-cart (store)
                        if (gameSource === "gog") return "\uf520"       // fa-compact-disc
                        if (gameSource === "amazon") return "\uf270"    // fa-amazon
                        if (gameSource === "heroic") return "\uf6d7"    // fa-dragon (Heroic)
                        if (gameSource === "config") return "\uf135"    // fa-rocket (launcher)
                        if (gameSource === "manual") return "\uf11b"    // fa-gamepad
                        return "\uf11b"  // fa-gamepad (default)
                    }
                }
            }

            // Category badge (bottom-right if platform exists, otherwise bottom-left)
            Rectangle {
                visible: gameCategory !== ""
                height: 24
                width: categoryText.width + 16
                radius: 12
                color: gameColors.color14 || "#555555"
                opacity: 0.9
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 8

                Text {
                    id: categoryText
                    anchors.centerIn: parent
                    text: gameCategory
                    font.pixelSize: 12
                    font.capitalization: Font.Capitalize
                    font.family: "Open Sans Regular"
                    font.bold: true
                    color: gameColors.color1 || "#ffffff"
                }
            }
        }

        // Game Name
        Rectangle {
            width: parent.width
            height: 60
            radius: card.radius
            color: "transparent"

            Text {
                anchors.fill: parent
                anchors.margins: 12
                text: gameName
                font.pixelSize: 14
                font.family: "Open Sans Regular"
                font.capitalization: Font.Capitalize
                font.bold: true
                color: gameColors.foreground || "#ffffff"
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Hover effect
    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: gameColors.color1 || "#00ffff"
        opacity: mouseArea.containsMouse ? 0.1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }
}
