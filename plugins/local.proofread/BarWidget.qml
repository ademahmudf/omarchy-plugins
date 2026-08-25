import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "local.proofread"

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string stateDir: homeDir + "/.local/state/omarchy/local.proofread"
  readonly property string settingsPath: stateDir + "/settings.json"

  property var settings: Model.DEFAULT_SETTINGS
  property string activeMode: "fix" // "fix" | "professional" | "concise" | "casual" | "translate"
  property string inputText: ""
  property string outputText: ""
  property bool isLoading: false
  property bool showSettings: false
  property bool popupOpen: false
  property bool copied: false
  property string errorMessage: ""

  readonly property string activeModelName: {
    if (settings.provider === "gemini") return settings.geminiModel || "gemini-1.5-flash"
    if (settings.provider === "groq") return settings.groqModel || "llama-3.3-70b"
    if (settings.provider === "openai") return settings.openaiModel || "gpt-4o-mini"
    return settings.ollamaModel || "ollama"
  }

  function open() {
    popupOpen = true
    showSettings = false
    copied = false
    errorMessage = ""
    readClipboardProc.running = true
    Qt.callLater(function() {
      if (inputArea) inputArea.forceActiveFocus()
    })
  }

  function close() {
    popupOpen = false
    showSettings = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function loadSettingsFromText(text) {
    root.settings = Model.parseSettingsJson(text)
  }

  function persistSettings() {
    settingsFile.setText(JSON.stringify(root.settings, null, 2) + "\n")
  }

  function copyResultAndClose(autoClose) {
    if (!outputText) return
    copyProc.command = ["wl-copy", outputText]
    copyProc.running = true
    root.copied = true
    if (autoClose) {
      Qt.callLater(function() { root.close() })
    }
  }

  function triggerProofread() {
    var text = String(inputText || "").trim()
    if (!text) return

    errorMessage = ""
    outputText = ""
    isLoading = true

    var systemPrompt = Model.getSystemPrompt(root.activeMode)
    var req = null

    if (settings.provider === "gemini") {
      if (!settings.apiKey) {
        isLoading = false
        showSettings = true
        errorMessage = "Please enter your Gemini API Key in Settings below."
        return
      }
      req = Model.buildGeminiRequest(settings.apiKey, settings.geminiModel, systemPrompt, text)
    } else if (settings.provider === "groq") {
      if (!settings.apiKey) {
        isLoading = false
        showSettings = true
        errorMessage = "Please enter your Groq API Key in Settings below."
        return
      }
      req = Model.buildOpenAiCompatibleRequest("https://api.groq.com/openai/v1", settings.apiKey, settings.groqModel, systemPrompt, text)
    } else if (settings.provider === "openai") {
      if (!settings.apiKey) {
        isLoading = false
        showSettings = true
        errorMessage = "Please enter your OpenAI API Key in Settings below."
        return
      }
      req = Model.buildOpenAiCompatibleRequest("https://api.openai.com/v1", settings.apiKey, settings.openaiModel, systemPrompt, text)
    } else {
      // Ollama (Local)
      req = Model.buildOpenAiCompatibleRequest(settings.ollamaEndpoint || "http://localhost:11434/v1", "", settings.ollamaModel || "llama3", systemPrompt, text)
    }

    sendHttpRequest(req.url, req.headers, req.body, function(success, responseText) {
      root.isLoading = false
      if (!success) {
        root.errorMessage = "Connection error: " + responseText
        return
      }
      if (root.settings.provider === "gemini") {
        var parsed = Model.parseGeminiResponse(responseText)
        if (parsed.startsWith("Error:")) {
          root.errorMessage = parsed
        } else {
          root.outputText = parsed
        }
      } else {
        var parsed = Model.parseOpenAiResponse(responseText)
        if (parsed.startsWith("Error:")) {
          root.errorMessage = parsed
        } else {
          root.outputText = parsed
        }
      }
    })
  }

  function sendHttpRequest(url, headers, body, callback) {
    var xhr = new XMLHttpRequest()
    xhr.open("POST", url, true)
    for (var key in headers) {
      if (headers.hasOwnProperty(key)) {
        xhr.setRequestHeader(key, headers[key])
      }
    }
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status >= 200 && xhr.status < 300) {
          callback(true, xhr.responseText)
        } else {
          callback(false, xhr.statusText + " (" + xhr.status + "): " + xhr.responseText)
        }
      }
    }
    xhr.send(body)
  }

  Process {
    id: initDirProc
    command: ["mkdir", "-p", root.stateDir]
    running: true
  }

  Process {
    id: copyProc
    command: ["wl-copy", ""]
  }

  Process {
    id: readClipboardProc
    command: ["wl-paste", "--no-newline"]
    stdout: StdioCollector {
      onDataChanged: {
        var raw = String(value || "").trim()
        if (raw && !root.inputText) {
          root.inputText = raw
        }
      }
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettingsFromText(text())
    onLoadFailed: root.loadSettingsFromText("")
    onFileChanged: reload()
  }

  IpcHandler {
    target: "local.proofread"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "AI Proofreader"
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : Math.ceil(iconItem.implicitWidth + Style.spaceReal(horizontalMargin) * 2)
    fixedHeight: root.vertical ? Math.ceil(iconItem.implicitHeight + Style.spaceReal(verticalPadding) * 2) : -1

    ProofreadIcon {
      id: iconItem
      anchors.centerIn: parent
      iconSize: Style.space(12)
      color: root.bar ? root.bar.barForeground : Color.foreground
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.open()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(Style.space(520))

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

            ProofreadIcon {
              iconSize: Style.space(16)
              color: Color.accent
            }

            Text {
              text: "Proofreader"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }
          }

          Row {
            anchors.right: parent.right
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter

            // Model Badge
            Rectangle {
              height: Style.space(20)
              width: modelBadgeText.implicitWidth + Style.space(10)
              radius: height / 2
              color: Style.hoverFillFor(Color.foreground, Color.accent)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                id: modelBadgeText
                anchors.centerIn: parent
                text: root.activeModelName
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Button {
              iconText: root.showSettings ? "󰅖" : "󰒓"
              tooltipText: root.showSettings ? "Back to Proofreader" : "Settings (API Key / Model)"
              fontSize: Style.font.bodySmall
              horizontalPadding: Style.space(5)
              verticalPadding: Style.space(2)
              onClicked: root.showSettings = !root.showSettings
            }
          }
        }

        // ---- Error Banner ---------------------------------------------------
        Rectangle {
          visible: root.errorMessage !== ""
          width: parent.width
          height: errorText.implicitHeight + Style.space(12)
          radius: Style.cornerRadius
          color: Style.hoverFillFor(Color.urgent, Color.urgent)
          border.width: 1
          border.color: Color.urgent

          Text {
            id: errorText
            anchors.fill: parent
            anchors.margins: Style.space(6)
            text: root.errorMessage
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        // ---- SETTINGS VIEW --------------------------------------------------
        Column {
          id: settingsView
          visible: root.showSettings
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "AI Provider Settings"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

          // Provider selector
          Row {
            width: parent.width
            spacing: Style.space(4)

            ProviderTab {
              label: "Gemini (Free)"
              providerKey: "gemini"
              activeProvider: root.settings.provider
              onClicked: {
                var s = Object.assign({}, root.settings, { provider: "gemini" })
                root.settings = s
                root.persistSettings()
              }
            }

            ProviderTab {
              label: "Groq (Fast)"
              providerKey: "groq"
              activeProvider: root.settings.provider
              onClicked: {
                var s = Object.assign({}, root.settings, { provider: "groq" })
                root.settings = s
                root.persistSettings()
              }
            }

            ProviderTab {
              label: "OpenAI"
              providerKey: "openai"
              activeProvider: root.settings.provider
              onClicked: {
                var s = Object.assign({}, root.settings, { provider: "openai" })
                root.settings = s
                root.persistSettings()
              }
            }

            ProviderTab {
              label: "Ollama (Local)"
              providerKey: "ollama"
              activeProvider: root.settings.provider
              onClicked: {
                var s = Object.assign({}, root.settings, { provider: "ollama" })
                root.settings = s
                root.persistSettings()
              }
            }
          }

          Text {
            visible: root.settings.provider !== "ollama"
            text: "API Key:"
            color: Qt.darker(Color.foreground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          TextField {
            id: apiKeyField
            visible: root.settings.provider !== "ollama"
            width: parent.width
            text: root.settings.apiKey || ""
            placeholderText: root.settings.provider === "gemini" ? "Paste Gemini API Key (from AI Studio)" : "Paste API Key"
            echoMode: TextInput.Password
            foreground: Color.foreground
            font.family: Style.font.family
            onTextChanged: {
              var s = Object.assign({}, root.settings, { apiKey: text })
              root.settings = s
            }
          }

          Text {
            visible: root.settings.provider === "gemini"
            text: "💡 Tip: You can get a 100% free Gemini API key at aistudio.google.com"
            color: Qt.darker(Color.foreground, 2.0)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Button {
            text: "Save & Return"
            iconText: "󰄬"
            fontSize: Style.font.bodySmall
            onClicked: {
              root.persistSettings()
              root.showSettings = false
              root.errorMessage = ""
            }
          }
        }

        // ---- MAIN PROOFREAD VIEW --------------------------------------------
        Column {
          id: proofreadView
          visible: !root.showSettings
          width: parent.width
          spacing: Style.space(8)

          // Tone / Mode Tabs
          Row {
            width: parent.width
            spacing: Style.space(4)

            ModeTab {
              label: "🛠️ Fix"
              modeKey: "fix"
              activeMode: root.activeMode
              onClicked: { root.activeMode = "fix"; if (root.inputText) root.triggerProofread() }
            }

            ModeTab {
              label: "👔 Work"
              modeKey: "professional"
              activeMode: root.activeMode
              onClicked: { root.activeMode = "professional"; if (root.inputText) root.triggerProofread() }
            }

            ModeTab {
              label: "⚡ Concise"
              modeKey: "concise"
              activeMode: root.activeMode
              onClicked: { root.activeMode = "concise"; if (root.inputText) root.triggerProofread() }
            }

            ModeTab {
              label: "💬 Casual"
              modeKey: "casual"
              activeMode: root.activeMode
              onClicked: { root.activeMode = "casual"; if (root.inputText) root.triggerProofread() }
            }

            ModeTab {
              label: "🌐 English"
              modeKey: "translate"
              activeMode: root.activeMode
              onClicked: { root.activeMode = "translate"; if (root.inputText) root.triggerProofread() }
            }
          }

          // Text Input Area
          Rectangle {
            width: parent.width
            height: Math.max(Style.space(85), inputArea.implicitHeight + Style.space(16))
            radius: Style.cornerRadius
            color: Style.hoverFillFor(Color.foreground, Color.accent)
            border.width: 1
            border.color: inputArea.activeFocus ? Color.accent : "transparent"

            TextArea {
              id: inputArea
              anchors.fill: parent
              anchors.margins: Style.space(8)
              text: root.inputText
              placeholderText: "Type or paste phrase here… (Ctrl+Enter to proofread)"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              onTextChanged: root.inputText = text

              Keys.onReturnPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier) {
                  root.triggerProofread()
                } else {
                  event.accepted = false
                }
              }
            }
          }

          // Action Buttons under Input
          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              text: root.isLoading ? "Polishing…" : "Proofread (Ctrl+Enter)"
              iconText: root.isLoading ? "󰑮" : "󰏫"
              enabled: !root.isLoading && root.inputText.trim() !== ""
              fontSize: Style.font.bodySmall
              onClicked: root.triggerProofread()
            }

            Button {
              text: "Paste Clipboard"
              iconText: "󰅇"
              fontSize: Style.font.caption
              onClicked: readClipboardProc.running = true
            }

            Button {
              visible: root.inputText !== ""
              iconText: "󰅖"
              tooltipText: "Clear text"
              fontSize: Style.font.caption
              onClicked: {
                root.inputText = ""
                root.outputText = ""
                root.errorMessage = ""
              }
            }
          }

          // Result Output Card (when available)
          Column {
            visible: root.outputText !== ""
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator {
              width: parent.width
              foreground: Color.foreground
            }

            Text {
              text: "Polished Result:"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Rectangle {
              width: parent.width
              height: outputResultText.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Style.selectedFillFor(Color.foreground, Color.accent)
              border.width: 1
              border.color: Color.accent

              Text {
                id: outputResultText
                anchors.fill: parent
                anchors.margins: Style.space(8)
                text: root.outputText
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
              }
            }

            Row {
              spacing: Style.space(6)

              Button {
                text: root.copied ? "Copied! ✓" : "Copy & Close"
                iconText: "󰄬"
                fontSize: Style.font.bodySmall
                onClicked: root.copyResultAndClose(true)
              }

              Button {
                text: "Copy"
                iconText: "󰆏"
                fontSize: Style.font.caption
                onClicked: root.copyResultAndClose(false)
              }

              Button {
                text: "Use as Input"
                iconText: "󰁔"
                fontSize: Style.font.caption
                onClicked: {
                  root.inputText = root.outputText
                  root.outputText = ""
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
            text: "Ctrl+Enter: Polish • Esc: Close"
            color: Qt.darker(Color.foreground, 2.2)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // Component for Mode Tabs
  component ModeTab: Rectangle {
    id: tabRoot
    required property string label
    required property string modeKey
    required property string activeMode
    signal clicked()

    readonly property bool active: modeKey === activeMode
    width: Math.max(tabText.implicitWidth + Style.space(10), (parent.width - Style.space(16)) / 5)
    height: Style.space(22)
    radius: Style.cornerRadius
    color: active ? Style.selectedFillFor(Color.foreground, Color.accent) : (tabHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : "transparent")

    Text {
      id: tabText
      anchors.centerIn: parent
      text: tabRoot.label
      color: tabRoot.active ? Color.accent : Qt.darker(Color.foreground, 1.3)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: tabRoot.active
    }

    MouseArea {
      id: tabHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tabRoot.clicked()
    }
  }

  // Component for Provider Tabs
  component ProviderTab: Rectangle {
    id: pTabRoot
    required property string label
    required property string providerKey
    required property string activeProvider
    signal clicked()

    readonly property bool active: providerKey === activeProvider
    width: Math.max(pTabText.implicitWidth + Style.space(10), (parent.width - Style.space(12)) / 4)
    height: Style.space(22)
    radius: Style.cornerRadius
    color: active ? Style.selectedFillFor(Color.foreground, Color.accent) : (pTabHover.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : "transparent")

    Text {
      id: pTabText
      anchors.centerIn: parent
      text: pTabRoot.label
      color: pTabRoot.active ? Color.accent : Qt.darker(Color.foreground, 1.3)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: pTabRoot.active
    }

    MouseArea {
      id: pTabHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pTabRoot.clicked()
    }
  }
}
