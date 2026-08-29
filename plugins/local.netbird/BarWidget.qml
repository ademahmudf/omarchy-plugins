import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "local.netbird"

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string stateDir: homeDir + "/.local/state/omarchy/local.netbird"
  readonly property string configPath: stateDir + "/config.json"

  property var config: Model.DEFAULT_CONFIG
  property var statusData: Model.parseNetbirdStatus("")
  property string authUrl: ""
  property string statusMessage: ""
  property string copiedText: ""
  property bool popupOpen: false
  property bool showAddCustom: false
  property string customNameDraft: ""
  property string customUrlDraft: ""
  property string peerSearchQuery: ""
  property int selectedProfileIndex: 0

  readonly property bool isConnected: statusData.isConnected
  readonly property bool isConnecting: statusData.isConnecting || connectProc.running
  readonly property bool needsLogin: statusData.needsLogin || (authUrl !== "" && !isConnected)
  readonly property bool isBusy: connectProc.running || disconnectProc.running

  // Resolve matching profile for current connection, or fallback to selected config profile
  readonly property var currentConnectedProfile: Model.findMatchingProfile(config.profiles, statusData.managementUrl)
  readonly property var activeProfile: currentConnectedProfile || getProfileById(config.selectedProfileId) || (config.profiles && config.profiles.length > 0 ? config.profiles[0] : null)
  readonly property var displayedPeers: Model.filterPeers(statusData.peers || [], peerSearchQuery)

  readonly property string tooltipText: {
    if (isConnected) {
      var profName = currentConnectedProfile ? currentConnectedProfile.name : "VPN"
      var ipStr = statusData.netbirdIp ? " (" + statusData.netbirdIp + ")" : ""
      return "NetBird — Connected to " + profName + ipStr
    } else if (isConnecting) {
      return "NetBird — Connecting to " + (activeProfile ? activeProfile.name : "VPN") + "…"
    } else if (needsLogin) {
      return "NetBird — Needs SSO Login (Click to authorize)"
    } else {
      return "NetBird — Disconnected (Middle-click to connect)"
    }
  }

  function getProfileById(id) {
    if (!config || !config.profiles) return null
    for (var i = 0; i < config.profiles.length; i++) {
      if (config.profiles[i] && config.profiles[i].id === id) {
        return config.profiles[i]
      }
    }
    return null
  }

  function open() {
    popupOpen = true
    showAddCustom = false
    refreshStatus()
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    popupOpen = false
    showAddCustom = false
    peerSearchQuery = ""
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function reloadConfigFile() {
    configFile.reload()
    refreshStatus()
  }

  function loadConfigFromText(text) {
    root.config = Model.parseConfigJson(text)
  }

  function persistConfig() {
    configFile.setText(JSON.stringify(root.config, null, 2) + "\n")
  }

  function refreshStatus() {
    if (!statusProc.running) {
      statusProc.running = true
    }
  }

  function connectToProfile(profile) {
    if (!profile || !profile.managementUrl) return
    root.config.selectedProfileId = profile.id
    persistConfig()

    root.authUrl = ""
    root.statusMessage = "Connecting to " + profile.name + "…"
    resetStatusTimer.restart()

    connectProc.command = ["netbird", "up", "--management-url", profile.managementUrl]
    connectProc.running = true

    // Accelerate polling while connecting
    fastPollTimer.restart()
  }

  function disconnectVpn() {
    root.authUrl = ""
    root.statusMessage = "Disconnecting from NetBird…"
    resetStatusTimer.restart()

    disconnectProc.command = ["netbird", "down"]
    disconnectProc.running = true

    fastPollTimer.restart()
  }

  function toggleConnection() {
    if (isConnected || isConnecting) {
      disconnectVpn()
    } else {
      var prof = activeProfile || (config.profiles && config.profiles.length > 0 ? config.profiles[0] : null)
      if (prof) connectToProfile(prof)
    }
  }

  function openAuthInBrowser() {
    if (authUrl) {
      Quickshell.execDetached(["xdg-open", authUrl])
      statusMessage = "Opening SSO login in browser… 🌐"
      resetStatusTimer.restart()
    }
  }

  function copyToClipboard(value, label) {
    var text = String(value || "").trim()
    if (!text) return
    clipboardProc.command = ["wl-copy", text]
    clipboardProc.running = true
    root.copiedText = text
    root.statusMessage = "Copied " + (label || "text") + "! ✓"
    resetCopiedTimer.restart()
    resetStatusTimer.restart()
  }

  function addCustomProfile(name, url) {
    var cleanName = String(name || "").trim()
    var cleanUrl = String(url || "").trim()
    if (!cleanName || !cleanUrl) return

    if (!cleanUrl.startsWith("http://") && !cleanUrl.startsWith("https://")) {
      cleanUrl = "https://" + cleanUrl
    }

    var newProf = {
      id: Model.generateId(),
      name: cleanName,
      managementUrl: cleanUrl,
      host: Model.extractHost(cleanUrl)
    }

    var list = root.config.profiles.slice()
    list.push(newProf)
    root.config.profiles = list
    root.config.selectedProfileId = newProf.id
    persistConfig()

    root.customNameDraft = ""
    root.customUrlDraft = ""
    root.showAddCustom = false
    root.statusMessage = "Added profile " + cleanName + "! ✓"
    resetStatusTimer.restart()

    connectToProfile(newProf)
  }

  function deleteCustomProfile(id) {
    if (id === "fliptech" || id === "dtktech") return // Protect default profiles
    var list = root.config.profiles.filter(function(p) { return p && p.id !== id })
    root.config.profiles = list
    if (root.config.selectedProfileId === id) {
      root.config.selectedProfileId = list.length > 0 ? list[0].id : "fliptech"
    }
    persistConfig()
    root.statusMessage = "Removed profile"
    resetStatusTimer.restart()
  }

  // --- Background Timers ---

  // Periodic Status Poller (every 5 seconds)
  Timer {
    id: regularPollTimer
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  // High-frequency Poller when connecting or authenticating (every 1.5 seconds)
  Timer {
    id: fastPollTimer
    interval: 1500
    repeat: true
    running: root.isConnecting || root.needsLogin
    onTriggered: {
      root.refreshStatus()
      if (!root.isConnecting && !root.needsLogin) {
        fastPollTimer.stop()
      }
    }
  }

  // Auto-reset copied feedback
  Timer {
    id: resetCopiedTimer
    interval: 2000
    onTriggered: root.copiedText = ""
  }

  // Auto-reset status message
  Timer {
    id: resetStatusTimer
    interval: 3500
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
    command: ["netbird", "status", "--json"]
    stdout: StdioCollector {
      id: statusStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: statusStderr
      waitForEnd: true
    }
    onExited: function(code) {
      var txt = String(statusStdout.text || "").trim()
      if (code === 0 && txt) {
        root.statusData = Model.parseNetbirdStatus(txt)
        if (root.statusData.isConnected && root.authUrl !== "") {
          root.authUrl = ""
        }
      } else {
        var errTxt = String(statusStderr.text || "").trim()
        if (errTxt) {
          root.statusData = Model.parseNetbirdStatus("")
        }
      }
    }
  }

  Process {
    id: connectProc
    stdout: StdioCollector {
      id: connectStdout
      waitForEnd: true
      onStreamFinished: {
        var detected = Model.extractAuthUrl(text)
        if (detected) {
          root.authUrl = detected
          fastPollTimer.restart()
        }
      }
    }
    stderr: StdioCollector {
      id: connectStderr
      waitForEnd: true
      onStreamFinished: {
        var detected = Model.extractAuthUrl(text)
        if (detected) {
          root.authUrl = detected
          fastPollTimer.restart()
        }
      }
    }
    onExited: function(code) {
      var raw = String(connectStdout.text || "") + "\n" + String(connectStderr.text || "")
      var detected = Model.extractAuthUrl(raw)
      if (detected) {
        root.authUrl = detected
      }
      root.refreshStatus()
    }
  }

  Process {
    id: disconnectProc
    command: ["netbird", "down"]
    onExited: function(code) {
      root.refreshStatus()
    }
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadConfigFromText(text())
    onLoadFailed: root.loadConfigFromText("")
    onFileChanged: reload()
  }

  // --- IPC Interface ---

  IpcHandler {
    target: "local.netbird"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function refresh(): void { root.refreshStatus() }
    function disconnect(): void { root.disconnectVpn() }
    function toggleVpn(): void { root.toggleConnection() }
    function connectFliptech(): void {
      var p = root.getProfileById("fliptech")
      if (p) root.connectToProfile(p)
    }
    function connectDtktech(): void {
      var p = root.getProfileById("dtktech")
      if (p) root.connectToProfile(p)
    }
    function connect(target: string): void {
      var p = root.getProfileById(target)
      if (p) {
        root.connectToProfile(p)
      } else {
        root.connectToProfile({ id: "custom", name: target, managementUrl: target })
      }
    }
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

    NetbirdIcon {
      id: iconItem
      anchors.centerIn: parent
      iconSize: Style.space(12)
      color: root.isConnected ? (root.bar ? root.bar.barForeground : Color.foreground) : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.6)
      connected: root.isConnected
      connecting: root.isConnecting
      needsLogin: root.needsLogin
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) {
        root.toggleConnection()
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
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(Style.space(500))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: (customNameInput && customNameInput.activeFocus) ||
               (customUrlInput && customUrlInput.activeFocus) ||
               (peerSearchInput && peerSearchInput.activeFocus)

      onCloseRequested: root.close()

      onActivateRequested: {
        root.toggleConnection()
      }

      onTextKey: function(t) {
        if (t === " ") {
          root.toggleConnection()
        } else if (t === "1" && root.config.profiles && root.config.profiles.length > 0) {
          root.connectToProfile(root.config.profiles[0])
        } else if (t === "2" && root.config.profiles && root.config.profiles.length > 1) {
          root.connectToProfile(root.config.profiles[1])
        } else if (t === "3" && root.config.profiles && root.config.profiles.length > 2) {
          root.connectToProfile(root.config.profiles[2])
        } else if (t === "a" || t === "+") {
          root.showAddCustom = !root.showAddCustom
        } else if (t === "r") {
          root.refreshStatus()
        } else if (t === "l" && root.authUrl !== "") {
          root.openAuthInBrowser()
        } else if (t === "c" && root.isConnected && root.statusData.netbirdIp) {
          root.copyToClipboard(root.statusData.netbirdIp, "NetBird IP")
        } else if (t === "/") {
          if (peerSearchInput) peerSearchInput.forceActiveFocus()
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
          policy: scroll.contentHeight > scroll.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
        }

        Column {
          id: mainColumn
          width: parent.width
          spacing: Style.space(10)

          // ---- Header --------------------------------------------------------
          Item {
            width: parent.width
            height: Math.max(headerRow.implicitHeight, switchBtn.implicitHeight)

            Row {
              id: headerRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              NetbirdIcon {
                iconSize: Style.space(18)
                color: root.isConnected ? Color.accent : Color.foreground
                connected: root.isConnected
                connecting: root.isConnecting
                needsLogin: root.needsLogin
                showBadge: false
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                  text: "NetBird VPN"
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                // Connection State Pill Subtitle
                Row {
                  spacing: Style.space(4)

                  Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.needsLogin ? Color.urgent : (root.isConnecting ? Color.accent : (root.isConnected ? "#2ecc71" : Qt.darker(Color.foreground, 2.0)))
                  }

                  Text {
                    text: root.isConnected ? "Connected" : (root.isConnecting ? "Connecting…" : (root.needsLogin ? "Needs SSO Login" : "Disconnected"))
                    color: root.isConnected ? "#2ecc71" : (root.isConnecting ? Color.accent : (root.needsLogin ? Color.urgent : Qt.darker(Color.foreground, 1.8)))
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }

            // Master On/Off Switch Button
            Button {
              id: switchBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.isConnected ? "Disconnect" : (root.isConnecting ? "Cancel" : "Connect")
              iconText: root.isConnected ? "󰅖" : (root.isConnecting ? "◌" : "󰐕")
              fontSize: Style.font.bodySmall
              foreground: root.isConnected ? Color.urgent : (root.isConnecting ? Color.foreground : Color.accent)
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(4)
              onClicked: root.toggleConnection()
            }
          }

          // ---- Status Toast Message -------------------------------------------
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

          // ---- SSO Authentication Required Banner -----------------------------
          Rectangle {
            id: ssoBanner
            visible: root.needsLogin || root.authUrl !== ""
            width: parent.width
            height: ssoCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: Style.selectedFillFor(Color.foreground, Color.urgent)
            border.width: 1
            border.color: Color.urgent

            Column {
              id: ssoCol
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Row {
                spacing: Style.space(6)

                Text {
                  text: "⚠️"
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: "SSO Login Required"
                  color: Color.urgent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                width: parent.width
                text: "Authentication is required to connect to this NetBird management server."
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Row {
                spacing: Style.space(6)

                Button {
                  text: "🌐 Open in Browser"
                  tooltipText: "Authorize device in browser (l)"
                  fontSize: Style.font.caption
                  foreground: Color.accent
                  onClicked: root.openAuthInBrowser()
                }

                Button {
                  visible: root.authUrl !== ""
                  text: "📋 Copy SSO Link"
                  tooltipText: "Copy login URL to clipboard"
                  fontSize: Style.font.caption
                  onClicked: root.copyToClipboard(root.authUrl, "SSO Link")
                }
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: Color.foreground
          }

          // ---- VPN Profiles / Gateways Section ---------------------------------
          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              height: Math.max(profHeaderRow.implicitHeight, addCustomBtn.implicitHeight)

              Row {
                id: profHeaderRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Text {
                  text: "VPN Gateways"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Text {
                  text: "(" + (root.config.profiles ? root.config.profiles.length : 0) + ")"
                  color: Qt.darker(Color.foreground, 1.8)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              Button {
                id: addCustomBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: root.showAddCustom ? "󰅖" : "󰐕"
                tooltipText: root.showAddCustom ? "Cancel (Esc)" : "Add Custom Gateway (a)"
                fontSize: Style.font.caption
                horizontalPadding: Style.space(4)
                verticalPadding: Style.space(2)
                onClicked: root.showAddCustom = !root.showAddCustom
              }
            }

            // Add Custom Gateway Inline Form
            Rectangle {
              visible: root.showAddCustom
              width: parent.width
              height: addCustomCol.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Style.hoverFillFor(Color.foreground, Color.accent)

              Column {
                id: addCustomCol
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(6)

                Text {
                  text: "Add Custom Management URL"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                TextField {
                  id: customNameInput
                  width: parent.width
                  placeholderText: "Profile Name (e.g. Staging Server)"
                  foreground: Color.foreground
                  font.family: Style.font.family
                  onTextChanged: root.customNameDraft = text
                  Keys.onEscapePressed: root.showAddCustom = false
                }

                TextField {
                  id: customUrlInput
                  width: parent.width
                  placeholderText: "Management URL (e.g. https://gate.example.com)"
                  foreground: Color.foreground
                  font.family: Style.font.family
                  onTextChanged: root.customUrlDraft = text
                  Keys.onEscapePressed: root.showAddCustom = false
                  onAccepted: root.addCustomProfile(customNameInput.text, customUrlInput.text)
                }

                Row {
                  spacing: Style.space(6)

                  Button {
                    text: "Save & Connect"
                    iconText: "󰄬"
                    fontSize: Style.font.caption
                    onClicked: root.addCustomProfile(customNameInput.text, customUrlInput.text)
                  }

                  Button {
                    text: "Cancel"
                    fontSize: Style.font.caption
                    onClicked: root.showAddCustom = false
                  }
                }
              }
            }

            // Profile List
            Repeater {
              id: profileRepeater
              model: root.config.profiles

              delegate: Item {
                id: profDelegate
                required property var modelData
                required property int index
                width: parent.width
                height: Math.max(Style.space(42), profRow.implicitHeight + Style.space(10))

                readonly property bool isCurrentConnected: root.isConnected && root.currentConnectedProfile && root.currentConnectedProfile.id === modelData.id
                readonly property bool isSelected: root.config.selectedProfileId === modelData.id
                readonly property bool isDefault: modelData.id === "fliptech" || modelData.id === "dtktech"

                Rectangle {
                  anchors.fill: parent
                  radius: Style.cornerRadius
                  color: profDelegate.isCurrentConnected
                    ? Style.selectedFillFor(Color.foreground, Color.accent)
                    : (profHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : "transparent")
                  border.width: profDelegate.isCurrentConnected ? 1 : 0
                  border.color: Color.accent
                }

                Row {
                  id: profRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  // Number badge (1, 2, 3...)
                  Rectangle {
                    width: Style.space(22)
                    height: Style.space(22)
                    radius: Style.cornerRadius
                    color: profDelegate.isCurrentConnected ? Color.accent : Style.normalFillFor(Color.foreground, Color.accent)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      anchors.centerIn: parent
                      text: profDelegate.isCurrentConnected ? "✓" : String(profDelegate.index + 1)
                      color: profDelegate.isCurrentConnected ? Color.background : Color.accent
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // Profile Name & URL
                  Column {
                    width: profRow.width - Style.space(22) - actionBtnRow.width - Style.space(24)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                      width: parent.width
                      text: profDelegate.modelData ? profDelegate.modelData.name : ""
                      color: profDelegate.isCurrentConnected ? Color.accent : Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: profDelegate.isCurrentConnected || profDelegate.isSelected
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: profDelegate.modelData ? (profDelegate.modelData.host || Model.extractHost(profDelegate.modelData.managementUrl)) : ""
                      color: Qt.darker(Color.foreground, 1.8)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  // Action Buttons
                  Row {
                    id: actionBtnRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Button {
                      visible: !profDelegate.isCurrentConnected
                      text: "Connect"
                      fontSize: Style.font.caption
                      horizontalPadding: Style.space(6)
                      verticalPadding: Style.space(2)
                      onClicked: root.connectToProfile(profDelegate.modelData)
                    }

                    Button {
                      visible: profDelegate.isCurrentConnected
                      text: "Active"
                      fontSize: Style.font.caption
                      foreground: "#2ecc71"
                      horizontalPadding: Style.space(6)
                      verticalPadding: Style.space(2)
                      onClicked: root.disconnectVpn()
                    }

                    Button {
                      visible: !profDelegate.isDefault && (profHover.hovered || profDelegate.isSelected)
                      iconText: "󰆴"
                      tooltipText: "Delete profile"
                      fontSize: Style.font.caption
                      foreground: Color.urgent
                      horizontalPadding: Style.space(4)
                      verticalPadding: Style.space(2)
                      onClicked: root.deleteCustomProfile(profDelegate.modelData.id)
                    }
                  }
                }

                TapHandler {
                  onTapped: {
                    if (profDelegate.isCurrentConnected) {
                      root.disconnectVpn()
                    } else {
                      root.connectToProfile(profDelegate.modelData)
                    }
                  }
                }

                HoverHandler {
                  id: profHover
                }
              }
            }
          }

          // ---- Connection Details Card (when connected) ------------------------
          Column {
            visible: root.isConnected
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator {
              width: parent.width
              foreground: Color.foreground
            }

            Text {
              text: "Connection Details"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Rectangle {
              width: parent.width
              height: detailsCol.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Style.hoverFillFor(Color.foreground, Color.accent)

              Column {
                id: detailsCol
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(6)

                // NetBird IP row
                Row {
                  width: parent.width
                  spacing: Style.space(6)

                  Text {
                    text: "NetBird IP:"
                    color: Qt.darker(Color.foreground, 1.6)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(90)
                  }

                  Text {
                    text: root.statusData.netbirdIp || "Unknown"
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: parent.width - Style.space(90) - copyIpBtn.width - Style.space(12)
                    elide: Text.ElideRight
                  }

                  Button {
                    id: copyIpBtn
                    text: root.copiedText === root.statusData.netbirdIp ? "Copied! ✓" : "Copy IP (c)"
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(5)
                    verticalPadding: Style.space(1)
                    onClicked: root.copyToClipboard(root.statusData.netbirdIp, "NetBird IP")
                  }
                }

                // Device FQDN row
                Row {
                  visible: root.statusData.fqdn !== ""
                  width: parent.width
                  spacing: Style.space(6)

                  Text {
                    text: "Device FQDN:"
                    color: Qt.darker(Color.foreground, 1.6)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(90)
                  }

                  Text {
                    text: root.statusData.fqdn || ""
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    width: parent.width - Style.space(90) - copyFqdnBtn.width - Style.space(12)
                    elide: Text.ElideRight
                  }

                  Button {
                    id: copyFqdnBtn
                    iconText: "󰆏"
                    tooltipText: "Copy FQDN"
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(4)
                    verticalPadding: Style.space(1)
                    onClicked: root.copyToClipboard(root.statusData.fqdn, "FQDN")
                  }
                }

                // Management URL row
                Row {
                  width: parent.width
                  spacing: Style.space(6)

                  Text {
                    text: "Gateway:"
                    color: Qt.darker(Color.foreground, 1.6)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(90)
                  }

                  Text {
                    text: root.statusData.managementUrl || ""
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    width: parent.width - Style.space(90) - Style.space(6)
                    elide: Text.ElideRight
                  }
                }

                // Peers online count row
                Row {
                  width: parent.width
                  spacing: Style.space(6)

                  Text {
                    text: "Peers Online:"
                    color: Qt.darker(Color.foreground, 1.6)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    width: Style.space(90)
                  }

                  Text {
                    text: (root.statusData.peersConnected || 0) + " / " + (root.statusData.peersTotal || 0) + " connected"
                    color: (root.statusData.peersConnected > 0) ? "#2ecc71" : Qt.darker(Color.foreground, 1.8)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          // ---- Connected Peers List (when peers exist) ------------------------
          Column {
            visible: root.isConnected && root.statusData.peers && root.statusData.peers.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator {
              width: parent.width
              foreground: Color.foreground
            }

            Item {
              width: parent.width
              height: peerHeaderRow.implicitHeight

              Row {
                id: peerHeaderRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Text {
                  text: "Peers & Devices"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Text {
                  text: "(" + root.displayedPeers.length + ")"
                  color: Qt.darker(Color.foreground, 1.8)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }

            // Search filter if more than 3 peers
            TextField {
              id: peerSearchInput
              visible: root.statusData.peers && root.statusData.peers.length > 3
              width: parent.width
              placeholderText: "Search peers… (/)"
              foreground: Color.foreground
              font.family: Style.font.family
              onTextChanged: root.peerSearchQuery = text
              Keys.onEscapePressed: {
                peerSearchInput.text = ""
                peerSearchInput.focus = false
                keyCatcher.forceActiveFocus()
              }
            }

            Repeater {
              id: peerRepeater
              model: root.displayedPeers

              delegate: Item {
                id: peerDelegate
                required property var modelData
                required property int index
                width: parent.width
                height: Math.max(Style.space(34), peerRow.implicitHeight + Style.space(8))

                readonly property bool isCopied: root.copiedText === (modelData ? modelData.netbirdIp : "")

                Rectangle {
                  anchors.fill: parent
                  radius: Style.cornerRadius
                  color: peerDelegate.isCopied
                    ? Style.selectedFillFor(Color.foreground, Color.accent)
                    : (peerHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : "transparent")
                }

                Row {
                  id: peerRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(6)

                  // Status dot
                  Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: (peerDelegate.modelData && peerDelegate.modelData.connected) ? "#2ecc71" : Qt.darker(Color.foreground, 2.0)
                  }

                  // Peer Name & FQDN
                  Column {
                    width: peerRow.width - Style.space(6) - copyPeerBtn.width - Style.space(20)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                      width: parent.width
                      text: (peerDelegate.modelData && peerDelegate.modelData.name) ? peerDelegate.modelData.name : "Peer"
                      color: Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: (peerDelegate.modelData && peerDelegate.modelData.netbirdIp) ? peerDelegate.modelData.netbirdIp : ""
                      color: Qt.darker(Color.foreground, 1.8)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  Button {
                    id: copyPeerBtn
                    text: peerDelegate.isCopied ? "✓" : "Copy"
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(4)
                    verticalPadding: Style.space(1)
                    onClicked: {
                      if (peerDelegate.modelData && peerDelegate.modelData.netbirdIp) {
                        root.copyToClipboard(peerDelegate.modelData.netbirdIp, peerDelegate.modelData.name + " IP")
                      }
                    }
                  }
                }

                TapHandler {
                  onTapped: {
                    if (peerDelegate.modelData && peerDelegate.modelData.netbirdIp) {
                      root.copyToClipboard(peerDelegate.modelData.netbirdIp, peerDelegate.modelData.name + " IP")
                    }
                  }
                }

                HoverHandler {
                  id: peerHover
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
              text: "Space: Toggle • 1/2: Gateways • c: Copy IP • Esc: Close"
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
