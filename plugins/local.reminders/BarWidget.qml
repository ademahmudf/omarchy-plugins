import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "local.reminders"

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string stateDir: homeDir + "/.local/state/omarchy/local.reminders"
  readonly property string remindersPath: stateDir + "/reminders.json"

  property var reminders: []
  property string activeFilter: "all" // "all" | "active" | "today" | "completed"
  property bool popupOpen: false
  property string editingReminderId: ""
  property string editDraft: ""
  property int selectedIndex: -1

  readonly property int pendingCount: Model.countPending(reminders)
  readonly property int completedCount: Model.countCompleted(reminders)
  readonly property var displayedReminders: Model.filterReminders(reminders, activeFilter)

  onDisplayedRemindersChanged: {
    if (selectedIndex >= displayedReminders.length) {
      selectedIndex = displayedReminders.length - 1
    }
  }

  readonly property string tooltipText: {
    if (pendingCount === 0) return "Reminders — all clear"
    return "Reminders — " + pendingCount + (pendingCount === 1 ? " task" : " tasks")
  }

  function open() {
    popupOpen = true
    selectedIndex = displayedReminders.length > 0 ? 0 : -1
    if (newReminderField) newReminderField.focus = false
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    if (editingReminderId !== "") cancelEdit()
    popupOpen = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function reloadFile() {
    remindersFile.reload()
  }

  function loadRemindersFromText(text) {
    var parsed = Model.parseRemindersJson(text)
    root.reminders = parsed
  }

  function persistReminders() {
    remindersFile.setText(JSON.stringify(root.reminders, null, 2) + "\n")
  }

  function addReminder(title) {
    var clean = Model.safeTrim(title)
    if (clean === "") return
    var item = {
      id: Model.generateId(),
      title: clean,
      completed: false,
      createdAt: Date.now(),
      completedAt: null
    }
    var list = root.reminders.slice()
    list.unshift(item)
    root.reminders = list
    persistReminders()
    if (newReminderField) newReminderField.text = ""
    root.selectedIndex = 0
  }

  function toggleCompleted(id) {
    var list = root.reminders.slice()
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].id === id) {
        var isNowCompleted = !list[i].completed
        list[i].completed = isNowCompleted
        list[i].completedAt = isNowCompleted ? Date.now() : null
        break
      }
    }
    root.reminders = list
    persistReminders()
  }

  function deleteReminder(id) {
    if (editingReminderId === id) cancelEdit()
    var list = root.reminders.filter(function(item) {
      return item && item.id !== id
    })
    root.reminders = list
    persistReminders()
  }

  function startEditing(id, currentTitle) {
    editingReminderId = id
    editDraft = currentTitle
  }

  function commitEdit(id) {
    var clean = Model.safeTrim(editDraft)
    if (clean !== "") {
      var list = root.reminders.slice()
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id === id) {
          list[i].title = clean
          break
        }
      }
      root.reminders = list
      persistReminders()
    }
    editingReminderId = ""
    editDraft = ""
    if (keyCatcher) keyCatcher.forceActiveFocus()
  }

  function cancelEdit() {
    editingReminderId = ""
    editDraft = ""
    if (keyCatcher) keyCatcher.forceActiveFocus()
  }

  function clearCompleted() {
    var list = root.reminders.filter(function(item) {
      return !item || !item.completed
    })
    root.reminders = list
    persistReminders()
  }

  function ensureItemVisible(idx) {
    if (!itemRepeater || idx < 0 || idx >= itemRepeater.count) return
    var item = itemRepeater.itemAt(idx)
    if (!item) return
    var pos = item.mapToItem(mainColumn, 0, 0)
    var itemTop = pos.y
    var itemBottom = pos.y + item.height
    if (itemTop < scroll.contentY) {
      scroll.contentY = Math.max(0, itemTop - Style.spacing.sm)
    } else if (itemBottom > scroll.contentY + scroll.height) {
      scroll.contentY = itemBottom - scroll.height + Style.spacing.sm
    }
  }

  Process {
    id: initDirProc
    command: ["mkdir", "-p", root.stateDir]
    running: true
  }

  FileView {
    id: remindersFile
    path: root.remindersPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadRemindersFromText(text())
    onLoadFailed: root.loadRemindersFromText("")
  }

  IpcHandler {
    target: "local.reminders"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function refresh(): void { root.reloadFile() }
    function add(text: string): void { root.addReminder(text) }
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

    ReminderIcon {
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
    contentHeight: popup.fittedContentHeight(Style.space(460))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: (newReminderField && newReminderField.activeFocus) || root.editingReminderId !== ""
      onCloseRequested: root.close()

      onMoveRequested: function(dx, dy) {
        var len = root.displayedReminders.length
        if (len === 0) return
        if (root.selectedIndex === -1) {
          root.selectedIndex = dy >= 0 ? 0 : len - 1
        } else {
          root.selectedIndex = Math.max(0, Math.min(len - 1, root.selectedIndex + dy))
        }
        root.ensureItemVisible(root.selectedIndex)
      }

      onActivateRequested: {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.displayedReminders.length) {
          var item = root.displayedReminders[root.selectedIndex]
          if (item) root.toggleCompleted(item.id)
        }
      }

      onDeleteRequested: {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.displayedReminders.length) {
          var item = root.displayedReminders[root.selectedIndex]
          if (item) root.deleteReminder(item.id)
        }
      }

      onTabRequested: function(dir) {
        var tabs = ["all", "active", "today", "completed"]
        var curIdx = tabs.indexOf(root.activeFilter)
        var nextIdx = (curIdx + dir + tabs.length) % tabs.length
        root.activeFilter = tabs[nextIdx]
      }

      onTextKey: function(t) {
        if (t === "a" || t === "n" || t === "q" || t === "/") {
          if (newReminderField) newReminderField.forceActiveFocus()
        } else if (t === "e" && root.selectedIndex >= 0 && root.selectedIndex < root.displayedReminders.length) {
          var item = root.displayedReminders[root.selectedIndex]
          if (item) root.startEditing(item.id, item.title)
        } else if (t === "1") {
          root.activeFilter = "all"
        } else if (t === "2") {
          root.activeFilter = "active"
        } else if (t === "3") {
          root.activeFilter = "today"
        } else if (t === "4") {
          root.activeFilter = "completed"
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

              ReminderIcon {
                iconSize: Style.space(16)
                color: Color.accent
              }

              Text {
                text: "Reminders"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }
            }

            Rectangle {
              anchors.right: parent.right
              width: badgeText.implicitWidth + Style.space(12)
              height: Style.space(20)
              radius: height / 2
              color: root.pendingCount > 0 ? Style.selectedFillFor(Color.foreground, Color.accent) : Style.hoverFillFor(Color.foreground, Color.accent)

              Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.pendingCount > 0 ? (root.pendingCount + " pending") : "All clear"
                color: root.pendingCount > 0 ? Color.accent : Qt.darker(Color.foreground, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }

          // ---- Filter Tabs ----------------------------------------------------
          Row {
            width: parent.width
            spacing: Style.space(4)

            TabButton {
              label: "All (" + root.reminders.length + ")"
              filterName: "all"
              currentFilter: root.activeFilter
              onClicked: root.activeFilter = "all"
            }

            TabButton {
              label: "Active (" + root.pendingCount + ")"
              filterName: "active"
              currentFilter: root.activeFilter
              onClicked: root.activeFilter = "active"
            }

            TabButton {
              label: "Today"
              filterName: "today"
              currentFilter: root.activeFilter
              onClicked: root.activeFilter = "today"
            }

            TabButton {
              label: "Done (" + root.completedCount + ")"
              filterName: "completed"
              currentFilter: root.activeFilter
              onClicked: root.activeFilter = "completed"
            }
          }

          // ---- Add Input Row --------------------------------------------------
          Row {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: newReminderField
              width: parent.width - addBtn.width - Style.space(6)
              focus: false
              placeholderText: "Add a reminder… (Press Enter)"
              foreground: Color.foreground
              font.family: Style.font.family
              onAccepted: {
                root.addReminder(text)
              }
              Keys.onEscapePressed: {
                newReminderField.focus = false
                keyCatcher.forceActiveFocus()
              }
              Keys.onDownPressed: {
                if (root.displayedReminders.length > 0) {
                  root.selectedIndex = 0
                  newReminderField.focus = false
                  keyCatcher.forceActiveFocus()
                }
              }
            }

            Button {
              id: addBtn
              iconText: "󰐕"
              tooltipText: "Add reminder (Enter)"
              fontSize: Style.font.body
              onClicked: {
                root.addReminder(newReminderField.text)
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: Color.foreground
          }

          // ---- Reminder List --------------------------------------------------
          Column {
            id: listColumn
            width: parent.width
            spacing: Style.space(4)
            visible: root.displayedReminders && root.displayedReminders.length > 0

            Repeater {
              id: itemRepeater
              model: root.displayedReminders

              delegate: Item {
                id: delegateItem
                required property var modelData
                required property int index
                width: listColumn.width
                height: Math.max(Style.space(36), rowLayout.implicitHeight + Style.space(12))

                readonly property bool isSelected: root.selectedIndex === delegateItem.index
                readonly property bool isEditing: root.editingReminderId === (modelData ? modelData.id : "")
                readonly property bool isDone: modelData ? modelData.completed === true : false

                Rectangle {
                  anchors.fill: parent
                  radius: Style.cornerRadius
                  color: delegateItem.isSelected ? Style.hoverFillFor(Color.foreground, Color.accent) : (rowHover.hovered ? Style.normalFillFor(Color.foreground, Color.accent) : "transparent")
                }

                Row {
                  id: rowLayout
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  // Checkbox
                  Item {
                    id: checkItem
                    width: Style.space(22)
                    height: Style.space(22)

                    Rectangle {
                      anchors.centerIn: parent
                      width: Style.space(18)
                      height: width
                      radius: width / 2
                      color: delegateItem.isDone ? Color.accent : "transparent"
                      border.width: Math.max(1, Style.space(1.5))
                      border.color: delegateItem.isDone ? Color.accent : (checkHover.hovered ? Color.accent : Qt.darker(Color.foreground, 1.6))

                      Text {
                        anchors.centerIn: parent
                        visible: delegateItem.isDone
                        text: "󰄬"
                        color: Color.background
                        font.family: Style.font.family
                        font.pixelSize: Style.space(11)
                        font.bold: true
                      }

                      Behavior on color { ColorAnimation { duration: 120 } }
                      Behavior on border.color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                      id: checkHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.toggleCompleted(delegateItem.modelData.id)
                    }
                  }

                  // Text Column
                  Column {
                    id: textCol
                    width: rowLayout.width - checkItem.width - (actionsRow.visible ? actionsRow.width : 0) - Style.space(16)
                    spacing: 2

                    Text {
                      visible: !delegateItem.isEditing
                      width: parent.width
                      text: (delegateItem.modelData && delegateItem.modelData.title) ? delegateItem.modelData.title : ""
                      color: delegateItem.isDone ? Qt.darker(Color.foreground, 1.8) : Color.foreground
                      font.strikeout: delegateItem.isDone
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      wrapMode: Text.Wrap
                    }

                    TextField {
                      id: inlineEditField
                      visible: delegateItem.isEditing
                      width: parent.width
                      text: root.editDraft
                      onTextChanged: if (delegateItem.isEditing) root.editDraft = text
                      onAccepted: root.commitEdit(delegateItem.modelData.id)
                      Keys.onEscapePressed: root.cancelEdit()

                      onVisibleChanged: {
                        if (visible) {
                          inlineEditField.forceActiveFocus()
                          inlineEditField.selectAll()
                        }
                      }
                    }

                    Text {
                      visible: !delegateItem.isEditing && delegateItem.modelData && delegateItem.modelData.createdAt
                      width: parent.width
                      text: delegateItem.modelData ? Model.formatRelativeDate(delegateItem.modelData.createdAt) : ""
                      color: Qt.darker(Color.foreground, 2.0)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // Hover Action Buttons
                  Row {
                    id: actionsRow
                    visible: (rowHover.hovered || delegateItem.isSelected) && !delegateItem.isEditing
                    spacing: Style.space(4)

                    Button {
                      iconText: "󰏫"
                      tooltipText: "Edit (e)"
                      fontSize: Style.font.caption
                      horizontalPadding: Style.space(4)
                      verticalPadding: Style.space(2)
                      onClicked: root.startEditing(delegateItem.modelData.id, delegateItem.modelData.title)
                    }

                    Button {
                      iconText: "󰆴"
                      tooltipText: "Delete (x)"
                      fontSize: Style.font.caption
                      foreground: Color.urgent
                      horizontalPadding: Style.space(4)
                      verticalPadding: Style.space(2)
                      onClicked: root.deleteReminder(delegateItem.modelData.id)
                    }
                  }
                }

                TapHandler {
                  onTapped: {
                    root.selectedIndex = delegateItem.index
                    keyCatcher.forceActiveFocus()
                  }
                  onDoubleTapped: {
                    root.startEditing(delegateItem.modelData.id, delegateItem.modelData.title)
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
            visible: !root.displayedReminders || root.displayedReminders.length === 0
            width: parent.width
            height: Style.space(70)

            Column {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.activeFilter === "completed" ? "No completed tasks yet" : (root.reminders.length === 0 ? "No reminders yet" : "No reminders matching filter")
                color: Qt.darker(Color.foreground, 1.8)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.reminders.length === 0 ? "Press 'a' or click above to add a reminder!" : "Great job staying organized! 🎉"
                color: Qt.darker(Color.foreground, 2.2)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          // ---- Footer --------------------------------------------------------
          Item {
            width: parent.width
            height: clearBtn.implicitHeight > 0 ? clearBtn.implicitHeight : footerText.implicitHeight

            Button {
              id: clearBtn
              visible: root.completedCount > 0
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Clear Done (" + root.completedCount + ")"
              fontSize: Style.font.caption
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: root.clearCompleted()
            }

            Text {
              id: footerText
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "↑↓: Nav • Space: Done • a: Add • Esc: Close"
              color: Qt.darker(Color.foreground, 2.2)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }

  // Segment Tab Helper Component
  component TabButton: Rectangle {
    id: tabRoot
    required property string label
    required property string filterName
    required property string currentFilter
    signal clicked()

    readonly property bool active: filterName === currentFilter
    width: Math.max(tabText.implicitWidth + Style.space(12), (parent.width - Style.space(12)) / 4)
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
}
