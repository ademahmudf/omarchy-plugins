import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "local.authenticator"

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string stateDir: homeDir + "/.local/state/omarchy/local.authenticator"
  readonly property string accountsPath: stateDir + "/accounts.json"
  readonly property string pluginDir: homeDir + "/.config/omarchy/plugins/local.authenticator"

  property var accounts: []
  property string searchQuery: ""
  property bool popupOpen: false
  property bool showAddView: false
  property string copiedAccountId: ""
  property string statusMessage: ""
  property int selectedIndex: -1
  property int nowSeconds: Math.floor(Date.now() / 1000)

  readonly property int remainingSeconds: 30 - (nowSeconds % 30)
  readonly property real progressRatio: remainingSeconds / 30.0
  readonly property var displayedAccounts: Model.filterAccounts(accounts, searchQuery)

  // Live 1-second tick for TOTP countdown
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      root.nowSeconds = Math.floor(Date.now() / 1000)
    }
  }

  // Auto-reset copied feedback
  Timer {
    id: resetCopiedTimer
    interval: 2000
    onTriggered: root.copiedAccountId = ""
  }

  // Auto-reset status message
  Timer {
    id: resetStatusTimer
    interval: 3500
    onTriggered: root.statusMessage = ""
  }

  readonly property string tooltipText: {
    var count = accounts.length
    if (count === 0) return "Authenticator — no accounts"
    return "Authenticator — " + count + (count === 1 ? " account" : " accounts") + " (" + remainingSeconds + "s)"
  }

  function open() {
    popupOpen = true
    showAddView = false
    selectedIndex = displayedAccounts.length > 0 ? 0 : -1
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    popupOpen = false
    showAddView = false
    searchQuery = ""
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function reloadFile() {
    accountsFile.reload()
  }

  function loadAccountsFromText(text) {
    root.accounts = Model.parseAccountsJson(text)
  }

  function persistAccounts() {
    accountsFile.setText(JSON.stringify(root.accounts, null, 2) + "\n")
  }

  function copyCode(acc) {
    if (!acc || !acc.secret) return
    var code = Model.generateTotp(acc.secret, acc.period || 30, acc.digits || 6, root.nowSeconds)
    clipboardProc.command = ["wl-copy", code]
    clipboardProc.running = true
    root.copiedAccountId = acc.id
    resetCopiedTimer.restart()
  }

  function addSingleAccount(issuer, account, secret) {
    var cleanSec = String(secret || "").replace(/\s+/g, "").toUpperCase()
    if (!cleanSec) return
    var item = {
      id: Model.generateId(),
      issuer: String(issuer || account || "Authenticator").trim(),
      account: String(account || "").trim(),
      secret: cleanSec,
      digits: 6,
      period: 30,
      algorithm: "SHA1",
      createdAt: Date.now()
    }
    var list = root.accounts.slice()
    list.push(item)
    root.accounts = list
    persistAccounts()
    showAddView = false
    statusMessage = "Added " + item.issuer + "! ✓"
    resetStatusTimer.restart()
  }

  function importUriOrData(inputStr) {
    var imported = Model.parseImportInput(inputStr)
    if (imported && imported.length > 0) {
      var list = root.accounts.slice()
      var addedCount = 0
      for (var i = 0; i < imported.length; i++) {
        var exists = list.some(function(a) { return a.secret === imported[i].secret })
        if (!exists) {
          list.push(imported[i])
          addedCount++
        }
      }
      root.accounts = list
      persistAccounts()
      showAddView = false
      statusMessage = "Imported " + addedCount + (addedCount === 1 ? " account" : " accounts") + "! 🎉"
      resetStatusTimer.restart()
      return addedCount
    }
    statusMessage = "Could not parse QR code or link"
    resetStatusTimer.restart()
    return 0
  }

  function deleteAccount(id) {
    var list = root.accounts.filter(function(a) { return a && a.id !== id })
    root.accounts = list
    persistAccounts()
  }

  function startScan(mode) {
    statusMessage = mode === "camera" ? "Scanning webcam… Hold phone up" : (mode === "screen" ? "Select area on screen…" : "Opening file picker…")
    if (mode === "screen") {
      root.close()
    }
    scannerProc.command = [root.pluginDir + "/scanner.sh", mode]
    scannerProc.running = true
  }

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
    id: scannerProc
    stdout: StdioCollector {
      onDataChanged: {
        var raw = String(value || "").trim()
        if (raw) {
          root.open()
          root.importUriOrData(raw)
        }
      }
    }
    onExited: function(code) {
      if (!root.popupOpen) root.open()
    }
  }

  FileView {
    id: accountsFile
    path: root.accountsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadAccountsFromText(text())
    onLoadFailed: root.loadAccountsFromText("[]")
    onFileChanged: reload()
  }

  IpcHandler {
    target: "local.authenticator"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function refresh(): void { root.reloadFile() }
    function importUri(uri: string): void { root.importUriOrData(uri) }
  }

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

    AuthIcon {
      id: iconItem
      anchors.centerIn: parent
      iconSize: Style.space(12)
      color: root.bar ? root.bar.barForeground : Color.foreground
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.reloadFile()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(350))
    contentHeight: popup.fittedContentHeight(Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: (searchInput && searchInput.activeFocus) || root.showAddView
      onCloseRequested: root.close()

      onMoveRequested: function(dx, dy) {
        var len = root.displayedAccounts.length
        if (len === 0) return
        if (root.selectedIndex === -1) {
          root.selectedIndex = dy >= 0 ? 0 : len - 1
        } else {
          root.selectedIndex = Math.max(0, Math.min(len - 1, root.selectedIndex + dy))
        }
      }

      onActivateRequested: {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.displayedAccounts.length) {
          var item = root.displayedAccounts[root.selectedIndex]
          if (item) root.copyCode(item)
        }
      }

      onDeleteRequested: {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.displayedAccounts.length) {
          var item = root.displayedAccounts[root.selectedIndex]
          if (item) root.deleteAccount(item.id)
        }
      }

      onTextKey: function(t) {
        if (t === "a" || t === "n" || t === "i") {
          root.showAddView = !root.showAddView
        } else if (t === "/") {
          if (searchInput) searchInput.forceActiveFocus()
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
            height: headerRow.implicitHeight

            Row {
              id: headerRow
              spacing: Style.space(8)

              AuthIcon {
                iconSize: Style.space(16)
                color: Color.accent
              }

              Text {
                text: "Authenticator"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }
            }

            // Countdown Timer Pill
            Row {
              anchors.right: parent.right
              spacing: Style.space(6)

              Rectangle {
                width: Style.space(18)
                height: Style.space(18)
                radius: width / 2
                color: Style.hoverFillFor(Color.foreground, Color.accent)
                anchors.verticalCenter: parent.verticalCenter

                // Circular fill progress
                Shape {
                  anchors.fill: parent
                  layer.enabled: true
                  layer.samples: 4

                  ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.remainingSeconds <= 5 ? Color.urgent : Color.accent
                    strokeWidth: 2.2
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                      centerX: 9
                      centerY: 9
                      radiusX: 7
                      radiusY: 7
                      startAngle: -90
                      sweepAngle: 360 * root.progressRatio
                    }
                  }
                }
              }

              Text {
                text: root.remainingSeconds + "s"
                color: root.remainingSeconds <= 5 ? Color.urgent : Qt.darker(Color.foreground, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Button {
                iconText: root.showAddView ? "󰅖" : "󰐕"
                tooltipText: root.showAddView ? "Back to accounts (Esc)" : "Add / Import (a)"
                fontSize: Style.font.bodySmall
                horizontalPadding: Style.space(5)
                verticalPadding: Style.space(2)
                onClicked: root.showAddView = !root.showAddView
              }
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

          // ---- Search / Filter Bar (when not in Add mode) ---------------------
          Item {
            visible: !root.showAddView && root.accounts.length > 3
            width: parent.width
            height: searchInput.implicitHeight

            TextField {
              id: searchInput
              anchors.fill: parent
              placeholderText: "Search accounts… (/)"
              foreground: Color.foreground
              font.family: Style.font.family
              onTextChanged: root.searchQuery = text
              Keys.onEscapePressed: {
                searchInput.text = ""
                searchInput.focus = false
                keyCatcher.forceActiveFocus()
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: Color.foreground
          }

          // ---- ADD / IMPORT VIEW ----------------------------------------------
          Column {
            id: addView
            visible: root.showAddView
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: "Import from Google Authenticator"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              width: parent.width
              text: "Export accounts in Google Authenticator on your phone, then scan or paste the export link:"
              color: Qt.darker(Color.foreground, 1.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              width: parent.width
              spacing: Style.space(4)

              Button {
                text: "📷 Webcam Scan"
                tooltipText: "Scan phone screen with laptop webcam"
                fontSize: Style.font.caption
                onClicked: root.startScan("camera")
              }

              Button {
                text: "🖼️ Select Image"
                tooltipText: "Select a photo/screenshot of the QR code"
                fontSize: Style.font.caption
                onClicked: root.startScan("file")
              }

              Button {
                text: "🖥️ Screen Area"
                tooltipText: "Select QR code on screen"
                fontSize: Style.font.caption
                onClicked: root.startScan("screen")
              }
            }

            TextField {
              id: importField
              width: parent.width
              placeholderText: "Or paste otpauth-migration:// or otpauth:// URI"
              foreground: Color.foreground
              font.family: Style.font.family
            }

            Button {
              text: "Import Link"
              iconText: "󰄬"
              fontSize: Style.font.caption
              onClicked: {
                var count = root.importUriOrData(importField.text)
                if (count > 0) importField.text = ""
              }
            }

            PanelSeparator {
              width: parent.width
              foreground: Color.foreground
            }

            Text {
              text: "Or Add Account Manually"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            TextField {
              id: manualIssuerField
              width: parent.width
              placeholderText: "Service / Issuer (e.g. GitHub, AWS)"
              foreground: Color.foreground
              font.family: Style.font.family
            }

            TextField {
              id: manualAccountField
              width: parent.width
              placeholderText: "Account / Email (e.g. user@gmail.com)"
              foreground: Color.foreground
              font.family: Style.font.family
            }

            TextField {
              id: manualSecretField
              width: parent.width
              placeholderText: "Secret Key (Base32)"
              foreground: Color.foreground
              font.family: Style.font.family
            }

            Button {
              text: "Save Account"
              iconText: "󰐕"
              fontSize: Style.font.bodySmall
              onClicked: {
                root.addSingleAccount(manualIssuerField.text, manualAccountField.text, manualSecretField.text)
                manualIssuerField.text = ""
                manualAccountField.text = ""
                manualSecretField.text = ""
              }
            }
          }

          // ---- ACCOUNTS LIST VIEW ---------------------------------------------
          Column {
            id: listColumn
            visible: !root.showAddView && root.displayedAccounts && root.displayedAccounts.length > 0
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              id: accountRepeater
              model: root.displayedAccounts

              delegate: Item {
                id: delegateItem
                required property var modelData
                required property int index
                width: listColumn.width
                height: Math.max(Style.space(44), rowLayout.implicitHeight + Style.space(12))

                readonly property bool isSelected: root.selectedIndex === delegateItem.index
                readonly property bool isCopied: root.copiedAccountId === (modelData ? modelData.id : "")
                readonly property string totpCode: modelData && modelData.secret
                  ? Model.generateTotp(modelData.secret, modelData.period || 30, modelData.digits || 6, root.nowSeconds)
                  : "------"

                Rectangle {
                  anchors.fill: parent
                  radius: Style.cornerRadius
                  color: delegateItem.isCopied
                    ? Style.selectedFillFor(Color.foreground, Color.accent)
                    : (delegateItem.isSelected
                      ? Style.hoverFillFor(Color.foreground, Color.accent)
                      : (rowHover.hovered ? Style.normalFillFor(Color.foreground, Color.accent) : "transparent"))
                }

                Row {
                  id: rowLayout
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  // Service Avatar Badge
                  Rectangle {
                    width: Style.space(26)
                    height: Style.space(26)
                    radius: Style.cornerRadius
                    color: Style.hoverFillFor(Color.foreground, Color.accent)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      anchors.centerIn: parent
                      text: (delegateItem.modelData && delegateItem.modelData.issuer)
                        ? delegateItem.modelData.issuer.charAt(0).toUpperCase()
                        : "A"
                      color: Color.accent
                      font.family: Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }
                  }

                  // Issuer & Account
                  Column {
                    id: textCol
                    width: rowLayout.width - Style.space(26) - codeBlock.width - (actionsRow.visible ? actionsRow.width : 0) - Style.space(24)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                      width: parent.width
                      text: (delegateItem.modelData && delegateItem.modelData.issuer) ? delegateItem.modelData.issuer : "Authenticator"
                      color: Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
                      visible: delegateItem.modelData && delegateItem.modelData.account !== ""
                      width: parent.width
                      text: delegateItem.modelData ? delegateItem.modelData.account : ""
                      color: Qt.darker(Color.foreground, 1.8)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  // TOTP Code & Copy Feedback
                  Item {
                    id: codeBlock
                    width: codeText.implicitWidth + Style.space(12)
                    height: Style.space(24)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                      anchors.fill: parent
                      radius: Style.cornerRadius
                      color: delegateItem.isCopied ? Color.accent : Style.normalFillFor(Color.foreground, Color.accent)

                      Text {
                        id: codeText
                        anchors.centerIn: parent
                        text: delegateItem.isCopied ? "Copied! ✓" : Model.formatCodeDisplay(delegateItem.totpCode)
                        color: delegateItem.isCopied ? Color.background : (root.remainingSeconds <= 5 ? Color.urgent : Color.accent)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                      }
                    }
                  }

                  // Delete action on hover
                  Row {
                    id: actionsRow
                    visible: (rowHover.hovered || delegateItem.isSelected) && !delegateItem.isCopied
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Button {
                      iconText: "󰆴"
                      tooltipText: "Delete account (x)"
                      fontSize: Style.font.caption
                      foreground: Color.urgent
                      horizontalPadding: Style.space(4)
                      verticalPadding: Style.space(2)
                      onClicked: root.deleteAccount(delegateItem.modelData.id)
                    }
                  }
                }

                TapHandler {
                  onTapped: {
                    root.selectedIndex = delegateItem.index
                    root.copyCode(delegateItem.modelData)
                    keyCatcher.forceActiveFocus()
                  }
                }

                HoverHandler {
                  id: rowHover
                }
              }
            }
          }

          // ---- Empty State ----------------------------------------------------
          Item {
            visible: !root.showAddView && (!root.displayedAccounts || root.displayedAccounts.length === 0)
            width: parent.width
            height: Style.space(90)

            Column {
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.accounts.length === 0 ? "No 2FA accounts added yet" : "No matching accounts"
                color: Qt.darker(Color.foreground, 1.8)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Import from Google Authenticator"
                iconText: "󰐕"
                fontSize: Style.font.caption
                onClicked: root.showAddView = true
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
              text: "Click/Enter: Copy Code • a: Add/Import • Esc: Close"
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
