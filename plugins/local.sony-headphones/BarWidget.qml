import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "local.sony-headphones"

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string stateDir: homeDir + "/.local/state/omarchy/local.sony-headphones"
  readonly property string stateFilePath: stateDir + "/state.json"
  readonly property string pluginDir: homeDir + "/.config/omarchy/plugins/local.sony-headphones"
  readonly property string controllerBin: pluginDir + "/bin/sony-controller"
  readonly property string controllerScript: pluginDir + "/controller.py"

  property var stateData: Model.DEFAULT_STATE
  property bool popupOpen: false
  property string statusMessage: ""
  property string copiedText: ""

  readonly property bool connected: stateData.connected === true
  readonly property string soundMode: stateData.soundMode || "anc"
  readonly property int ambientLevel: stateData.ambientLevel || 12
  readonly property bool voiceFocus: stateData.voiceFocus === true
  readonly property bool speakToChat: stateData.speakToChat === true
  readonly property string activeEq: stateData.equalizer || "off"
  readonly property string deviceName: (stateData.device && stateData.device.name) ? stateData.device.name : "Sony Headphones"
  readonly property int battery: (stateData.device && typeof stateData.device.battery === "number") ? stateData.device.battery : -1
  readonly property string firmware: (stateData.device && stateData.device.firmware) ? stateData.device.firmware : ""
  readonly property string codec: (stateData.device && stateData.device.codec) ? stateData.device.codec : ""
  readonly property int eqLow: (stateData.eq && typeof stateData.eq.low === "number") ? stateData.eq.low : 0
  readonly property int eqMid: (stateData.eq && typeof stateData.eq.mid === "number") ? stateData.eq.mid : 0
  readonly property int eqHigh: (stateData.eq && typeof stateData.eq.high === "number") ? stateData.eq.high : 0
  readonly property string eqPreset: (stateData.eq && stateData.eq.preset) ? stateData.eq.preset : "flat"
  readonly property bool eqEnabled: stateData.eq && stateData.eq.enabled === true

  readonly property string tooltipText: {
    if (!connected) return "Sony Headphones — Disconnected"
    var modeStr = Model.formatSoundModeTitle(soundMode)
    var battStr = battery >= 0 ? " (" + battery + "%)" : ""
    var metaStr = (codec ? " • " + codec : "") + (firmware ? " • FW " + firmware : "")
    return deviceName + " — " + modeStr + battStr + metaStr + " • Middle-click to cycle"
  }

  function open() {
    popupOpen = true
    refreshStatus()
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    popupOpen = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function runAction(args) {
    actionProc.running = false
    actionProc.command = [root.controllerBin].concat(args)
    actionProc.running = true
  }

  function refreshStatus() {
    statusProc.running = false
    statusProc.command = [root.controllerBin, "status"]
    statusProc.running = true
  }

  function setSoundMode(mode) {
    var nextState = Object.assign({}, root.stateData)
    nextState.soundMode = mode
    root.stateData = nextState
    runAction(["set-mode", mode])
    var title = Model.formatSoundModeTitle(mode)
    statusMessage = "Set mode: " + title
    resetStatusTimer.restart()
  }

  function cycleSoundMode() {
    var nextMode = soundMode === "anc" ? "ambient" : (soundMode === "ambient" ? "off" : "anc")
    setSoundMode(nextMode)
  }

  function setAmbientLevel(lvl) {
    runAction(["set-ambient", String(lvl)])
  }

  function toggleVoiceFocus() {
    runAction(["toggle-voice-focus"])
    statusMessage = !voiceFocus ? "Voice Focus Enabled ✓" : "Voice Focus Disabled"
    resetStatusTimer.restart()
  }

  function toggleSpeakToChat() {
    var next = !speakToChat
    runAction(["set-speak-to-chat", next ? "on" : "off"])
    statusMessage = next ? "Speak-to-Chat ON ✓" : "Speak-to-Chat OFF"
    resetStatusTimer.restart()
  }

  function setCustomEqLow(lvl) {
    runAction(["set-eq-low", String(lvl)])
  }

  function setCustomEqMid(lvl) {
    runAction(["set-eq-mid", String(lvl)])
  }

  function setCustomEqHigh(lvl) {
    runAction(["set-eq-high", String(lvl)])
  }

  function setCustomEqPreset(preset) {
    runAction(["set-eq-preset", preset])
    statusMessage = "EQ Preset: " + preset
    resetStatusTimer.restart()
  }

  function resetCustomEq() {
    runAction(["reset-eq"])
    statusMessage = "Equalizer Reset (Flat) ✓"
    resetStatusTimer.restart()
  }

  function setEqualizer(preset) {
    runAction(["set-eq", preset])
    statusMessage = "EQ: " + preset
    resetStatusTimer.restart()
  }

  function copyToClipboard(text, label) {
    if (!text) return
    clipboardProc.command = ["wl-copy", text]
    clipboardProc.running = true
    copiedText = text
    statusMessage = "Copied " + (label || "text") + "! ✓"
    resetCopiedTimer.restart()
    resetStatusTimer.restart()
  }

  // --- Background Timers ---

  Timer {
    id: pollTimer
    interval: 4000
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: resetCopiedTimer
    interval: 2000
    onTriggered: root.copiedText = ""
  }

  Timer {
    id: resetStatusTimer
    interval: 3000
    onTriggered: root.statusMessage = ""
  }

  // --- Process Handlers ---

  Process {
    id: initDirProc
    command: ["mkdir", "-p", root.stateDir]
    running: true
  }

  Process {
    id: clipboardProc
    command: ["wl-copy", ""]
  }

  Process {
    id: statusProc
    command: [root.controllerScript, "status"]
    stdout: StdioCollector {
      id: statusStdout
      waitForEnd: true
    }
    onExited: function(code) {
      if (code === 0 && statusStdout.text) {
        root.stateData = Model.parseStateJson(statusStdout.text)
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      id: actionStdout
      waitForEnd: true
    }
    onExited: function(code) {
      if (code === 0 && actionStdout.text) {
        root.stateData = Model.parseStateJson(actionStdout.text)
      } else {
        root.refreshStatus()
      }
    }
  }

  FileView {
    id: stateFile
    path: root.stateFilePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.stateData = Model.parseStateJson(text())
    onLoadFailed: root.stateData = Model.DEFAULT_STATE
    onFileChanged: reload()
  }

  // --- IPC Interface ---

  IpcHandler {
    target: "local.sony-headphones"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function refresh(): void { root.refreshStatus() }
    function cycleMode(): void { root.cycleSoundMode() }
    function setAnc(): void { root.setSoundMode("anc") }
    function setAmbient(): void { root.setSoundMode("ambient") }
    function setOff(): void { root.setSoundMode("off") }
    function setMode(mode: string): void { root.setSoundMode(mode) }
    function setAmbientLevel(level: int): void { root.setAmbientLevel(level) }
    function toggleVoiceFocus(): void { root.toggleVoiceFocus() }
    function toggleSpeakToChat(): void { root.toggleSpeakToChat() }
    function setEq(preset: string): void { root.setEqualizer(preset) }
  }

  // --- Bar Button ---

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltipText
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : Math.ceil(iconItem.implicitWidth + Style.spaceReal(horizontalMargin) * 2)
    fixedHeight: root.vertical ? Math.ceil(iconItem.implicitHeight + Style.spaceReal(verticalPadding) * 2) : -1

    SonyIcon {
      id: iconItem
      anchors.centerIn: parent
      iconSize: Style.space(12)
      color: root.connected ? (root.bar ? root.bar.barForeground : Color.foreground) : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.6)
      connected: root.connected
      soundMode: root.soundMode
      battery: root.battery
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) {
        root.cycleSoundMode()
      } else {
        root.toggle()
      }
    }
  }

  // --- Popup Panel ---

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(350))
    contentHeight: popup.fittedContentHeight(Math.min(Style.space(640), mainColumn.implicitHeight + Style.space(24)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      onActivateRequested: {
        root.cycleSoundMode()
      }

      onTextKey: function(t) {
        if (t === " ") {
          root.cycleSoundMode()
        } else if (t === "1") {
          root.setSoundMode("anc")
        } else if (t === "2") {
          root.setSoundMode("ambient")
        } else if (t === "3") {
          root.setSoundMode("off")
        } else if (t === "s") {
          root.toggleSpeakToChat()
        } else if (t === "v") {
          root.toggleVoiceFocus()
        } else if (t === "r") {
          root.refreshStatus()
        } else if (t === "+" || t === "=" || t === "]") {
          root.setAmbientLevel(Math.min(20, root.ambientLevel + 1))
        } else if (t === "-" || t === "_" || t === "[") {
          root.setAmbientLevel(Math.max(1, root.ambientLevel - 1))
        }
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AlwaysOff
        }

        Column {
          id: mainColumn
          width: parent.width
          spacing: Style.space(10)

          // ---- Header --------------------------------------------------------
          Item {
            width: parent.width
            height: headerRow.implicitHeight

            Row {
              id: headerRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              SonyIcon {
                iconSize: Style.space(18)
                color: Color.accent
                connected: root.connected
                soundMode: root.soundMode
                showBadge: false
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                  text: root.deviceName
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Row {
                  spacing: Style.space(4)

                  Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.connected ? "#2ecc71" : Qt.darker(Color.foreground, 2.0)
                  }

                  Text {
                    text: root.connected ? ("Connected" + (root.firmware ? " • FW " + root.firmware : "")) : "Not Connected"
                    color: root.connected ? "#2ecc71" : Qt.darker(Color.foreground, 1.8)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            // Right Badges Row (Codec & Battery)
            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              // Codec Badge Pill
              Rectangle {
                visible: root.connected && root.codec !== ""
                width: codecText.implicitWidth + Style.space(12)
                height: Style.space(22)
                radius: height / 2
                color: Style.selectedFillFor(Color.foreground, Color.accent)
                border.width: 1
                border.color: Color.accent

                Text {
                  id: codecText
                  anchors.centerIn: parent
                  text: root.codec
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              // Battery Badge Pill
              Rectangle {
                visible: root.connected && root.battery >= 0
                width: battRow.implicitWidth + Style.space(12)
                height: Style.space(22)
                radius: height / 2
                color: root.battery <= 20 ? Style.selectedFillFor(Color.foreground, Color.urgent) : Style.hoverFillFor(Color.foreground, Color.accent)

                Row {
                  id: battRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: root.battery > 80 ? "󰂂" : (root.battery > 50 ? "󰁾" : (root.battery > 20 ? "󰁼" : "󰁺"))
                    color: root.battery <= 20 ? Color.urgent : Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: root.battery + "%"
                    color: root.battery <= 20 ? Color.urgent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }
          }

          // ---- Status Toast Feedback ------------------------------------------
          Rectangle {
            visible: root.statusMessage !== ""
            width: parent.width
            height: Style.space(24)
            radius: Style.cornerRadius
            color: Style.selectedFillFor(Color.foreground, Color.accent)

            Text {
              anchors.centerIn: parent
              text: root.statusMessage
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: Color.foreground
          }

          // ---- Sound Mode Section (One-Line Segmented Row) --------------------
          Column {
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: "Sound Control Mode"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            // 1-Line Mode Selector Bar (3 equal width segments)
            Row {
              width: parent.width
              spacing: Style.space(6)

              // 1. ANC Mode Segment (Headphones Icon)
              Rectangle {
                width: Math.floor((parent.width - Style.space(12)) / 3)
                height: Style.space(38)
                radius: Style.cornerRadius
                color: root.soundMode === "anc" ? Style.selectedFillFor(Color.foreground, Color.accent) : (ancHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : Style.normalFillFor(Color.foreground, Color.accent))
                border.width: root.soundMode === "anc" ? 1.2 : 0
                border.color: Color.accent

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    text: "󰋋"
                    color: root.soundMode === "anc" ? Color.accent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.icon
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "ANC"
                    color: root.soundMode === "anc" ? Color.accent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: root.soundMode === "anc"
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: ancHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setSoundMode("anc")
                }
              }

              // 2. Ambient Mode Segment (Speaker Icon)
              Rectangle {
                width: Math.floor((parent.width - Style.space(12)) / 3)
                height: Style.space(38)
                radius: Style.cornerRadius
                color: root.soundMode === "ambient" ? Style.selectedFillFor(Color.foreground, Color.accent) : (ambHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : Style.normalFillFor(Color.foreground, Color.accent))
                border.width: root.soundMode === "ambient" ? 1.2 : 0
                border.color: Color.accent

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    text: "󰕾"
                    color: root.soundMode === "ambient" ? Color.accent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.icon
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "Ambient"
                    color: root.soundMode === "ambient" ? Color.accent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: root.soundMode === "ambient"
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: ambHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setSoundMode("ambient")
                }
              }

              // 3. Off Mode Segment (Speaker 0 Volume / Muted Icon)
              Rectangle {
                width: Math.floor((parent.width - Style.space(12)) / 3)
                height: Style.space(38)
                radius: Style.cornerRadius
                color: root.soundMode === "off" ? Style.selectedFillFor(Color.foreground, Color.accent) : (offHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : Style.normalFillFor(Color.foreground, Color.accent))
                border.width: root.soundMode === "off" ? 1.2 : 0
                border.color: Color.accent

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    text: "󰝟"
                    color: root.soundMode === "off" ? Color.accent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.icon
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "Off"
                    color: root.soundMode === "off" ? Color.accent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: root.soundMode === "off"
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: offHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setSoundMode("off")
                }
              }
            }

            // Ambient Sound Slider Card (Shown when ambient mode is active)
            Rectangle {
              visible: root.soundMode === "ambient"
              width: parent.width
              height: ambientInnerCol.implicitHeight + Style.space(14)
              radius: Style.cornerRadius
              color: Style.hoverFillFor(Color.foreground, Color.accent)
              border.width: 1
              border.color: Style.selectedFillFor(Color.foreground, Color.accent)

              Column {
                id: ambientInnerCol
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(6)

                Item {
                  width: parent.width
                  height: Math.max(ambLvlText.implicitHeight, voiceFocusBtn.implicitHeight)

                  Text {
                    id: ambLvlText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Ambient Level: " + (ambientSlider.dragging ? Math.round(ambientSlider.liveValue) : root.ambientLevel) + " / 20"
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Button {
                    id: voiceFocusBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.voiceFocus ? "🗣️ Voice Focus: ON" : "🗣️ Voice Focus: OFF"
                    fontSize: Style.font.caption
                    foreground: root.voiceFocus ? Color.accent : Qt.darker(Color.foreground, 1.5)
                    horizontalPadding: Style.space(6)
                    verticalPadding: Style.space(2)
                    onClicked: root.toggleVoiceFocus()
                  }
                }

                // Slider Row
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: "1"
                    color: Qt.darker(Color.foreground, 1.8)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  PanelSlider {
                    id: ambientSlider
                    width: parent.width - Style.space(46)
                    bar: root.bar
                    minimum: 1
                    maximum: 20
                    step: 1
                    integer: true
                    value: root.ambientLevel
                    trackColor: Style.selectedFillFor(Color.foreground, Color.accent)
                    fillColor: Color.accent
                    knobColor: Color.accent
                    anchors.verticalCenter: parent.verticalCenter
                    onReleased: function(val) {
                      root.setAmbientLevel(Math.round(val))
                    }
                  }

                  Text {
                    text: "20"
                    color: Qt.darker(Color.foreground, 1.8)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: Color.foreground
          }

          // ---- Smart Features & Speak-to-Chat ---------------------------------
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "Features & Presets"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            // Speak-to-Chat Toggle Card (Clean 1-line)
            Rectangle {
              width: parent.width
              height: Style.space(38)
              radius: Style.cornerRadius
              color: root.speakToChat ? Style.selectedFillFor(Color.foreground, Color.accent) : Style.hoverFillFor(Color.foreground, Color.accent)

              Item {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)

                Row {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(8)

                  Text {
                    text: "🗣️"
                    font.pixelSize: Style.space(14)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "Speak-to-Chat"
                    color: root.speakToChat ? Color.accent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: root.speakToChat
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Button {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.speakToChat ? "ON" : "OFF"
                  fontSize: Style.font.caption
                  foreground: root.speakToChat ? "#2ecc71" : Qt.darker(Color.foreground, 1.5)
                  horizontalPadding: Style.space(8)
                  verticalPadding: Style.space(2)
                  onClicked: root.toggleSpeakToChat()
                }
              }
            }

            // ---- Graphic Equalizer (Standard Audio EQ) --------------------------
            Column {
              width: parent.width
              spacing: Style.space(6)

              Item {
                width: parent.width
                height: Math.max(eqTitleText.implicitHeight, resetEqBtn.implicitHeight)

                Text {
                  id: eqTitleText
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Equalizer"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Button {
                  id: resetEqBtn
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "↺ Flat"
                  fontSize: Style.font.caption
                  foreground: (root.eqLow !== 0 || root.eqMid !== 0 || root.eqHigh !== 0) ? Color.accent : Qt.darker(Color.foreground, 1.8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: Style.space(1)
                  onClicked: root.resetCustomEq()
                }
              }

              // Preset Selector Chips
              Flow {
                width: parent.width
                spacing: Style.space(4)

                Repeater {
                  model: Model.EQ_PRESETS

                  delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: eqText.implicitWidth + Style.space(12)
                    height: Style.space(22)
                    radius: Style.cornerRadius
                    color: root.eqPreset === modelData.id ? Color.accent : (eqHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : Style.normalFillFor(Color.foreground, Color.accent))

                    Text {
                      id: eqText
                      anchors.centerIn: parent
                      text: modelData.name
                      color: root.eqPreset === modelData.id ? Color.background : Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: root.eqPreset === modelData.id
                    }

                    MouseArea {
                      id: eqHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setCustomEqPreset(modelData.id)
                    }
                  }
                }
              }

              // Graphic EQ Rack Container (3 Vertical Sliders)
              Rectangle {
                width: parent.width
                height: Style.space(118)
                radius: Style.cornerRadius
                color: Style.hoverFillFor(Color.foreground, Color.accent)
                border.width: (root.eqLow !== 0 || root.eqMid !== 0 || root.eqHigh !== 0) ? 1.2 : 0
                border.color: Color.accent

                // Center 0 dB Reference Line across the rack
                Rectangle {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: Style.space(26)
                  anchors.rightMargin: Style.space(10)
                  y: Style.space(56)
                  height: 1
                  color: Qt.darker(Color.foreground, 2.4)
                }

                // Reference Marks Labels (+15, 0, -15) on extreme left
                Text {
                  text: "+15"
                  color: Qt.darker(Color.foreground, 2.4)
                  font.pixelSize: Style.font.caption - 2
                  x: Style.space(4)
                  y: Style.space(24)
                }
                Text {
                  text: "0"
                  color: Qt.darker(Color.foreground, 2.4)
                  font.pixelSize: Style.font.caption - 2
                  x: Style.space(8)
                  y: Style.space(50)
                }
                Text {
                  text: "-15"
                  color: Qt.darker(Color.foreground, 2.4)
                  font.pixelSize: Style.font.caption - 2
                  x: Style.space(4)
                  y: Style.space(76)
                }

                Row {
                  id: fadersRow
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(28)
                  anchors.rightMargin: Style.space(10)
                  anchors.topMargin: Style.space(6)
                  anchors.bottomMargin: Style.space(6)
                  spacing: Style.space(8)

                  // Band 1: Low (120 Hz)
                  Item {
                    id: lowFader
                    width: Math.floor((fadersRow.width - Style.space(16)) / 3)
                    height: parent.height

                    property int liveVal: root.eqLow
                    property bool dragging: false
                    onLiveValChanged: if (!dragging) liveVal = root.eqLow

                    Text {
                      id: lowValLabel
                      anchors.top: parent.top
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: (lowFader.liveVal > 0 ? "+" : "") + lowFader.liveVal
                      color: lowFader.liveVal !== 0 ? Color.accent : Qt.darker(Color.foreground, 1.8)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    Item {
                      id: lowTrackBox
                      anchors.top: lowValLabel.bottom
                      anchors.topMargin: Style.space(2)
                      anchors.bottom: lowInfoCol.top
                      anchors.bottomMargin: Style.space(2)
                      width: Style.space(28)
                      anchors.horizontalCenter: parent.horizontalCenter

                      Rectangle {
                        width: 4
                        radius: 2
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Style.selectedFillFor(Color.foreground, Color.accent)
                      }

                      Rectangle {
                        id: lowKnob
                        width: Style.space(14)
                        height: Style.space(14)
                        radius: width / 2
                        color: lowFader.liveVal !== 0 ? Color.accent : Color.foreground
                        border.width: 1.5
                        border.color: Color.background
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.max(0, Math.min(lowTrackBox.height - height, (15 - lowFader.liveVal) / 30 * (lowTrackBox.height - height)))

                        scale: (lowFader.dragging || lowHover.hovered) ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                      }

                      MouseArea {
                        id: lowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateY(my) {
                          var usableH = lowTrackBox.height - lowKnob.height
                          var cy = Math.max(0, Math.min(usableH, my - lowKnob.height / 2))
                          var norm = cy / usableH
                          var raw = 15 - (norm * 30)
                          lowFader.liveVal = Math.max(-15, Math.min(15, Math.round(raw)))
                        }

                        onPressed: function(mouse) {
                          lowFader.dragging = true
                          updateY(mouse.y)
                        }
                        onPositionChanged: function(mouse) {
                          if (lowFader.dragging) updateY(mouse.y)
                        }
                        onReleased: function() {
                          lowFader.dragging = false
                          root.setCustomEqLow(lowFader.liveVal)
                        }
                        onWheel: function(wheel) {
                          var delta = wheel.angleDelta.y > 0 ? 1 : -1
                          var next = Math.max(-15, Math.min(15, lowFader.liveVal + delta))
                          lowFader.liveVal = next
                          root.setCustomEqLow(next)
                        }
                      }
                      HoverHandler { id: lowHover }
                    }

                    Column {
                      id: lowInfoCol
                      anchors.bottom: parent.bottom
                      anchors.horizontalCenter: parent.horizontalCenter
                      spacing: 0

                      Text {
                        text: "Low"
                        color: lowFader.liveVal !== 0 ? Color.accent : Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                      }
                      Text {
                        text: "120Hz"
                        color: Qt.darker(Color.foreground, 2.0)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        anchors.horizontalCenter: parent.horizontalCenter
                      }
                    }
                  }

                  // Band 2: Mid (1.2 kHz)
                  Item {
                    id: midFader
                    width: Math.floor((fadersRow.width - Style.space(16)) / 3)
                    height: parent.height

                    property int liveVal: root.eqMid
                    property bool dragging: false
                    onLiveValChanged: if (!dragging) liveVal = root.eqMid

                    Text {
                      id: midValLabel
                      anchors.top: parent.top
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: (midFader.liveVal > 0 ? "+" : "") + midFader.liveVal
                      color: midFader.liveVal !== 0 ? Color.accent : Qt.darker(Color.foreground, 1.8)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    Item {
                      id: midTrackBox
                      anchors.top: midValLabel.bottom
                      anchors.topMargin: Style.space(2)
                      anchors.bottom: midInfoCol.top
                      anchors.bottomMargin: Style.space(2)
                      width: Style.space(28)
                      anchors.horizontalCenter: parent.horizontalCenter

                      Rectangle {
                        width: 4
                        radius: 2
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Style.selectedFillFor(Color.foreground, Color.accent)
                      }

                      Rectangle {
                        id: midKnob
                        width: Style.space(14)
                        height: Style.space(14)
                        radius: width / 2
                        color: midFader.liveVal !== 0 ? Color.accent : Color.foreground
                        border.width: 1.5
                        border.color: Color.background
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.max(0, Math.min(midTrackBox.height - height, (15 - midFader.liveVal) / 30 * (midTrackBox.height - height)))

                        scale: (midFader.dragging || midHover.hovered) ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                      }

                      MouseArea {
                        id: midMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateY(my) {
                          var usableH = midTrackBox.height - midKnob.height
                          var cy = Math.max(0, Math.min(usableH, my - midKnob.height / 2))
                          var norm = cy / usableH
                          var raw = 15 - (norm * 30)
                          midFader.liveVal = Math.max(-15, Math.min(15, Math.round(raw)))
                        }

                        onPressed: function(mouse) {
                          midFader.dragging = true
                          updateY(mouse.y)
                        }
                        onPositionChanged: function(mouse) {
                          if (midFader.dragging) updateY(mouse.y)
                        }
                        onReleased: function() {
                          midFader.dragging = false
                          root.setCustomEqMid(midFader.liveVal)
                        }
                        onWheel: function(wheel) {
                          var delta = wheel.angleDelta.y > 0 ? 1 : -1
                          var next = Math.max(-15, Math.min(15, midFader.liveVal + delta))
                          midFader.liveVal = next
                          root.setCustomEqMid(next)
                        }
                      }
                      HoverHandler { id: midHover }
                    }

                    Column {
                      id: midInfoCol
                      anchors.bottom: parent.bottom
                      anchors.horizontalCenter: parent.horizontalCenter
                      spacing: 0

                      Text {
                        text: "Mid"
                        color: midFader.liveVal !== 0 ? Color.accent : Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                      }
                      Text {
                        text: "1.2kHz"
                        color: Qt.darker(Color.foreground, 2.0)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        anchors.horizontalCenter: parent.horizontalCenter
                      }
                    }
                  }

                  // Band 3: High (5.5 kHz)
                  Item {
                    id: highFader
                    width: Math.floor((fadersRow.width - Style.space(16)) / 3)
                    height: parent.height

                    property int liveVal: root.eqHigh
                    property bool dragging: false
                    onLiveValChanged: if (!dragging) liveVal = root.eqHigh

                    Text {
                      id: highValLabel
                      anchors.top: parent.top
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: (highFader.liveVal > 0 ? "+" : "") + highFader.liveVal
                      color: highFader.liveVal !== 0 ? Color.accent : Qt.darker(Color.foreground, 1.8)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    Item {
                      id: highTrackBox
                      anchors.top: highValLabel.bottom
                      anchors.topMargin: Style.space(2)
                      anchors.bottom: highInfoCol.top
                      anchors.bottomMargin: Style.space(2)
                      width: Style.space(28)
                      anchors.horizontalCenter: parent.horizontalCenter

                      Rectangle {
                        width: 4
                        radius: 2
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Style.selectedFillFor(Color.foreground, Color.accent)
                      }

                      Rectangle {
                        id: highKnob
                        width: Style.space(14)
                        height: Style.space(14)
                        radius: width / 2
                        color: highFader.liveVal !== 0 ? Color.accent : Color.foreground
                        border.width: 1.5
                        border.color: Color.background
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.max(0, Math.min(highTrackBox.height - height, (15 - highFader.liveVal) / 30 * (highTrackBox.height - height)))

                        scale: (highFader.dragging || highHover.hovered) ? 1.25 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                      }

                      MouseArea {
                        id: highMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateY(my) {
                          var usableH = highTrackBox.height - highKnob.height
                          var cy = Math.max(0, Math.min(usableH, my - highKnob.height / 2))
                          var norm = cy / usableH
                          var raw = 15 - (norm * 30)
                          highFader.liveVal = Math.max(-15, Math.min(15, Math.round(raw)))
                        }

                        onPressed: function(mouse) {
                          highFader.dragging = true
                          updateY(mouse.y)
                        }
                        onPositionChanged: function(mouse) {
                          if (highFader.dragging) updateY(mouse.y)
                        }
                        onReleased: function() {
                          highFader.dragging = false
                          root.setCustomEqHigh(highFader.liveVal)
                        }
                        onWheel: function(wheel) {
                          var delta = wheel.angleDelta.y > 0 ? 1 : -1
                          var next = Math.max(-15, Math.min(15, highFader.liveVal + delta))
                          highFader.liveVal = next
                          root.setCustomEqHigh(next)
                        }
                      }
                      HoverHandler { id: highHover }
                    }

                    Column {
                      id: highInfoCol
                      anchors.bottom: parent.bottom
                      anchors.horizontalCenter: parent.horizontalCenter
                      spacing: 0

                      Text {
                        text: "High"
                        color: highFader.liveVal !== 0 ? Color.accent : Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                      }
                      Text {
                        text: "5.5kHz"
                        color: Qt.darker(Color.foreground, 2.0)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        anchors.horizontalCenter: parent.horizontalCenter
                      }
                    }
                  }
                }
              }
            }
          }

          // ---- Footer --------------------------------------------------------
          Item {
            width: parent.width
            height: footerText.implicitHeight

            Text {
              id: footerText
              anchors.centerIn: parent
              text: "1: ANC • 2: Ambient • 3: Off • Space: Cycle • Esc: Close"
              color: Qt.darker(Color.foreground, 2.2)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
