import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "ivan"
  readonly property string hostName: Quickshell.env("HOSTNAME") || "ivan"
  readonly property string userHost: userName + "@" + hostName
  property string lockTimeString: Qt.formatTime(new Date(), "HH:mm")

  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, 2, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, 2, "border-alpha")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) {
      lockTimeString = Qt.formatTime(new Date(), "HH:mm")
      Qt.callLater(forcePasswordFocus)
    }
  }
  Component.onCompleted: {
    lockTimeString = Qt.formatTime(new Date(), "HH:mm")
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // Terminal window container
    BorderSurface {
      id: terminalWindow
      width: 720
      height: 430
      anchors.centerIn: parent
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: 12
      clip: true

      // Header / Titlebar
      Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 38
        color: Qt.rgba(0, 0, 0, 0.4)

        // Terminal window buttons (macOS / modern Unix style)
        Row {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          Rectangle {
            width: 12
            height: 12
            radius: 6
            color: "#bf5a7c"
          }

          Rectangle {
            width: 12
            height: 12
            radius: 6
            color: "#dfec63"
          }

          Rectangle {
            width: 12
            height: 12
            radius: 6
            color: "#62e2a4"
          }
        }

        // Title text
        Text {
          anchors.centerIn: parent
          text: "terminal — " + root.userHost
          font.family: Style.font.family
          font.pixelSize: 12
          font.bold: true
          color: "#888888"
        }
      }

      // Terminal content area
      Item {
        id: terminalBody
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24

        // Shell prompt and command lines
        Text {
          id: promptOutput
          anchors.top: parent.top
          anchors.topMargin: 8
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.right: parent.right
          anchors.rightMargin: 8
          textFormat: Text.RichText
          font.family: Style.font.family
          font.pixelSize: 13
          lineHeight: 1.35
          color: Color.foreground
          text: "<span style='color:#62e2a4;'><b>" + root.userHost + "</b></span>:<span style='color:#9ed8dd;'><b>~</b></span>$ lock-session --status<br/>" +
                "<span style='color:#62e2a4;'>●</span> Active session locked at " + root.lockTimeString + "<br/><br/>" +
                "<span style='color:#62e2a4;'><b>" + root.userHost + "</b></span>:<span style='color:#9ed8dd;'><b>~</b></span>$ sudo auth-unlock<br/>" +
                "<span style='color:#aaaaaa;'>[sudo] password for " + root.userName + ":</span>"
        }

        // Input field box styled as terminal command prompt
        Rectangle {
          id: inputContainer
          anchors.top: promptOutput.bottom
          anchors.topMargin: 20
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.right: parent.right
          anchors.rightMargin: 8
          height: 44
          radius: 6
          color: Qt.rgba(0, 0, 0, 0.35)
          border.width: 1
          border.color: root.errorState ? "#bf5a7c" : (passwordInput.activeFocus ? Color.lock.borderActive : Qt.rgba(1, 1, 1, 0.15))

          MouseArea {
            anchors.fill: parent
            onClicked: root.forcePasswordFocus()
          }

          Text {
            id: promptSymbol
            text: "❯"
            font.family: Style.font.family
            font.pixelSize: 14
            font.bold: true
            color: "#62e2a4"
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
          }

          TextInput {
            id: passwordInput
            anchors.left: promptSymbol.right
            anchors.leftMargin: 10
            anchors.right: root.fingerprintConfigured ? fingerprintIcon.left : parent.right
            anchors.rightMargin: root.fingerprintConfigured ? 10 : 14
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            verticalAlignment: TextInput.AlignVCenter
            activeFocusOnPress: true
            clip: true
            enabled: root.inputEnabled && !root.authenticatingPassword
            readOnly: root.authenticatingPassword
            echoMode: TextInput.Password
            passwordCharacter: "\u25CF"
            passwordMaskDelay: 0
            color: Color.lock.text
            selectionColor: Color.lock.selection
            selectedTextColor: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: 14
            font.letterSpacing: 2
            cursorVisible: activeFocus && root.showPasswordCursor

            cursorDelegate: Rectangle {
              width: 2
              color: "#62e2a4"
              visible: passwordInput.cursorVisible
            }

            onTextChanged: {
              if (!root.syncingPasswordText) root.passwordTextEdited(text)
              if (text.length > 0) root.wakeRequested()
              if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
            }

            onAccepted: {
              var submitted = root.passwordText
              root.passwordTextEdited("")
              if (submitted.length > 0) root.submitPassword(submitted)
            }

            Keys.onPressed: function(event) {
              root.wakeRequested()
              if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                root.passwordTextEdited("")
                event.accepted = true
              }
            }
          }

          // Placeholder / Feedback Text
          Text {
            anchors.left: promptSymbol.right
            anchors.leftMargin: 10
            anchors.right: root.fingerprintConfigured ? fingerprintIcon.left : parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: passwordInput.text.length === 0
            textFormat: Text.RichText
            font.family: Style.font.family
            font.pixelSize: 13
            text: {
              if (root.authenticatingPassword) {
                return "<span style='color:#aaaaaa;'><i>Checking…</i></span>"
              }
              if (root.failureMessage.length > 0) {
                return "<span style='color:#bf5a7c;'><b>[FAILED]</b> Incorrect password (" + root.failedAttempts + ")</span>"
              }
              return "<span style='color:#666666;'><i>Enter password...</i></span>"
            }
          }

          // Fingerprint icon if enrolled
          Text {
            id: fingerprintIcon
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: root.fingerprintConfigured
            text: "󰈷"
            color: Color.lock.placeholder
            font.family: Style.font.family
            font.pixelSize: 16
          }
        }

        // Bottom helper hint
        Text {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 4
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Enter: unlock • ESC: clear buffer"
          font.family: Style.font.family
          font.pixelSize: 11
          color: "#555555"
        }
      }
    }
  }
}
