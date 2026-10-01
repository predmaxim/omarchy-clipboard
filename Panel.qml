import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
// History format, capture and paste all belong to the built-in clipboard
// manager (omarchy.clipboard, Super+Ctrl+V); this widget is a second view of
// the same file. If an Omarchy update moves this file, the widget stops
// loading — look for the new place in $OMARCHY_PATH/shell/plugins/clipboard.
import "qs:@/qs/plugins/clipboard/ClipboardHistory.js" as ClipboardHistory
import "I18n.js" as I18n

Panel {
  id: root
  moduleName: "predmaxim.clipboard"
  ipcTarget: "predmaxim.clipboard"

  // Interface text in the system's language (I18n.js).
  readonly property var tr: I18n.translator(I18n.textLanguage(function(name) { return Quickshell.env(name) }))
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property string pasteScript: Qt.resolvedUrl("paste.sh").toString().replace(/^file:\/\//, "")
  // The built-in manager never keeps more than 300 entries.
  readonly property int maxLimit: 300
  readonly property int limit: Math.max(1, Math.min(maxLimit, parseInt(setting("limit", 50)) || 50))
  property var history: []
  property bool ready: false
  property bool editingLimit: false
  property int selectedIndex: 0

  readonly property var rows: ClipboardHistory.displayRows(history, searchField.text, limit)

  function save(next) {
    root.history = next
    file.setText(JSON.stringify(next, null, 2) + "\n")
  }

  // The built-in manager appends to its own copy and writes the whole list
  // back; it reloads the file on change, so trimming here sticks.
  function trim() {
    if (root.ready && root.history.length > root.limit) save(root.history.slice(0, root.limit))
  }

  function remove(index) {
    if (index < 0 || index >= root.rows.length) return
    save(ClipboardHistory.removeEntryAt(root.history, root.rows[index].index))
    root.selectedIndex = Math.min(root.selectedIndex, root.rows.length - 1)
  }

  // Copy the entry back to the clipboard, then paste into the window that
  // regains focus. Text goes through the built-in helper; images and files
  // through paste.sh, which gives terminals their paths instead.
  function paste(index) {
    if (index < 0 || index >= root.rows.length) return
    var row = root.rows[index]
    root.close()
    if (row.entryType === "image")
      Quickshell.execDetached([root.pasteScript, "image", row.mime, row.path])
    else if (row.entryType === "file")
      Quickshell.execDetached([root.pasteScript, "files", String(row.index)].concat(ClipboardHistory.filePaths(root.history[row.index])))
    else
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-text", "--history-index", String(row.index)])
  }

  function move(delta) {
    if (root.rows.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.rows.length) % root.rows.length
    list.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  // Same write path as the built-in clock: the value lands inline on this
  // widget's shell.json entry and comes back as root.settings.
  function setLimit(value) {
    var n = parseInt(value)
    if (n > 0) {
      var entry = { id: root.moduleName }
      for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
      entry.limit = Math.min(root.maxLimit, n)
      root.settings = entry
      if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
        root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
    root.editingLimit = false
    searchField.forceActiveFocus()
  }

  onLimitChanged: trim()
  onOpenedChanged: {
    root.editingLimit = false
    searchField.text = ""
    root.selectedIndex = 0
    if (opened) list.positionViewAtBeginning()
  }

  readonly property bool present: history.length > 0
  onPresentChanged: if (!present) close()
  visible: present
  implicitWidth: present ? button.implicitWidth : 0
  implicitHeight: present ? button.implicitHeight : 0

  FileView {
    id: file
    path: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { root.history = ClipboardHistory.parseHistory(text()); root.ready = true; root.trim() }
    onLoadFailed: root.history = []
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰅌"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.present
    focusTarget: searchField
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: limitField.activeFocus || searchField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { root.move(dy) }
      onActivateRequested: root.paste(root.selectedIndex)
      onDeleteRequested: root.remove(root.selectedIndex)
      Keys.onDeletePressed: root.remove(root.selectedIndex)

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        PanelHero {
          title: root.tr("Clipboard")
          meta: root.tr("Entries")
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          iconComponent: Text {
            text: "󰅌"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
          }
          trailingControl: Row {
            spacing: Style.space(12)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.rows.length
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\uf013"
              iconSize: Style.font.body
              tooltipText: root.tr("How many to keep")
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              selected: root.editingLimit
              onClicked: {
                root.editingLimit = !root.editingLimit
                if (root.editingLimit) {
                  limitField.text = String(root.limit)
                  limitField.forceActiveFocus()
                  limitField.selectAll()
                } else searchField.forceActiveFocus()
              }
            }
          }
        }

        // Typing goes here from the start; the list keys that aren't text
        // (arrows, Enter, Delete, Esc, Tab) are handled on the field itself.
        TextField {
          id: searchField
          width: parent.width
          placeholderText: root.tr("Search")
          foreground: root.bar.foreground
          font.family: root.bar.fontFamily
          onTextChanged: { root.selectedIndex = 0; list.positionViewAtBeginning() }
          onAccepted: root.paste(root.selectedIndex)
          Keys.onUpPressed: root.move(-1)
          Keys.onDownPressed: root.move(1)
          Keys.onDeletePressed: root.remove(root.selectedIndex)
          Keys.onEscapePressed: { if (text) text = ""; else root.close() }
          Keys.onTabPressed: root.switchPanel(1)
          Keys.onBacktabPressed: root.switchPanel(-1)
        }

        Column {
          visible: root.editingLimit
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: root.tr("How many entries to keep (1–%1) · Enter saves", root.maxLimit).toUpperCase()
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }

          TextField {
            id: limitField
            width: parent.width
            foreground: root.bar.foreground
            font.family: root.bar.fontFamily
            validator: IntValidator { bottom: 1; top: root.maxLimit }
            onAccepted: root.setLimit(text)
            Keys.onEscapePressed: { root.editingLimit = false; searchField.forceActiveFocus() }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Text {
          visible: root.rows.length === 0
          text: root.tr("Nothing found")
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          id: list
          width: parent.width
          height: Math.min(contentHeight, Style.space(560))
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.rows

          delegate: CursorSurface {
            id: row
            required property var modelData
            required property int index
            width: list.width
            implicitHeight: Math.max(labels.implicitHeight, thumb.height, deleteButton.implicitHeight) + Style.spacing.xl
            foreground: root.bar.foreground
            hasCursor: root.selectedIndex === index

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selectedIndex = row.index
              onClicked: root.paste(row.index)
            }

            Item {
              id: thumb
              width: Style.space(40)
              height: row.modelData.previewImage ? Style.space(40) : icon.implicitHeight
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter

              Image {
                anchors.fill: parent
                visible: !!row.modelData.previewImage
                source: row.modelData.previewImage ? Util.fileUrl(row.modelData.previewImage) : ""
                sourceSize.width: Style.space(80)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

              Text {
                id: icon
                visible: !row.modelData.previewImage
                anchors.centerIn: parent
                text: row.modelData.entryType === "file" ? "󰈔" : "󰦨"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
              }
            }

            Column {
              id: labels
              anchors.left: thumb.right
              anchors.leftMargin: Style.space(10)
              anchors.right: deleteButton.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: row.modelData.previewText
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: row.modelData.entryType === "text"
                maximumLineCount: 2
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                visible: row.modelData.entryType !== "text"
                textFormat: Text.PlainText
                text: row.modelData.entryType === "file" ? row.modelData.path || root.tr("Files") : root.tr("Image")
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideMiddle
                width: parent.width
              }
            }

            Button {
              id: deleteButton
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\uf1f8"
              iconSize: Style.font.body
              tooltipText: root.tr("Delete")
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              onClicked: root.remove(row.index)
            }
          }
        }
      }
    }
  }
}
