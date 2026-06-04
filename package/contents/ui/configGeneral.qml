import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQControls
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: root

    // cfg_ properties bind the form to config/main.xml entries.
    // (Twitch Client ID is baked into the widget; users just link. Kick needs
    // their own app credentials, handled by the Connect button further down.)
    property alias cfg_channels: channelsField.text
    property alias cfg_kickChannels: kickChannelsField.text
    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_useCurlResume: curlResumeCheck.checked
    property alias cfg_fontSize: fontSpin.value
    property alias cfg_orientation: orientationCombo.currentIndex
    property alias cfg_hAlign: hAlignCombo.currentIndex
    property alias cfg_vAlign: vAlignCombo.currentIndex
    property alias cfg_hoverDelay: hoverSpin.value
    property string cfg_fontColor: ""
    property string cfg_fontFamily: ""

    // Border / background — widget-level frame
    property alias cfg_widgetFrameEnabled: widgetFrame.frameEnabled
    property alias cfg_widgetBorderWidth: widgetFrame.borderWidth
    property alias cfg_widgetCornerStyle: widgetFrame.cornerStyle
    property alias cfg_widgetCornerRadius: widgetFrame.cornerRadius
    property alias cfg_widgetBorderColor: widgetFrame.borderColor
    property alias cfg_widgetFillOpacity: widgetFrame.fillOpacity
    property alias cfg_widgetFillMode: widgetFrame.fillMode
    property alias cfg_widgetFillColors: widgetFrame.fillColors

    // Border / background — per-streamer chip frame
    property alias cfg_chipFrameEnabled: chipFrame.frameEnabled
    property alias cfg_chipBorderWidth: chipFrame.borderWidth
    property alias cfg_chipCornerStyle: chipFrame.cornerStyle
    property alias cfg_chipCornerRadius: chipFrame.cornerRadius
    property alias cfg_chipBorderColor: chipFrame.borderColor
    property alias cfg_chipFillOpacity: chipFrame.fillOpacity
    property alias cfg_chipFillMode: chipFrame.fillMode
    property alias cfg_chipFillColors: chipFrame.fillColors

    // NOTE: linked / linkRequested / unlinkRequested are deliberately NOT exposed
    // as cfg_ properties. The shell only round-trips keys that have a matching
    // cfg_ property, so leaving them off means the Apply cycle never touches the
    // tokens. The Link/Unlink button instead writes Plasmoid.configuration
    // directly for an immediate, live effect.

    readonly property var fontFamilies: Qt.fontFamilies()

    // Kick app names must be unique on the platform, so the suggested name gets
    // a random hex suffix. n = number of hex digits.
    function randomHex(n) {
        var chars = "0123456789abcdef";
        var s = "";
        for (var i = 0; i < n; i++)
            s += chars.charAt(Math.floor(Math.random() * 16));
        return s;
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Channels")
                Kirigami.FormData.isSection: true
            }

            QQC2.TextArea {
                id: channelsField
                Kirigami.FormData.label: i18n("Twitch channels:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                Layout.minimumHeight: Kirigami.Units.gridUnit * 5
                wrapMode: TextEdit.WrapAnywhere
                placeholderText: i18n("e.g.\nshroud\nxqc\nsummit1g")
            }

            QQC2.TextArea {
                id: kickChannelsField
                Kirigami.FormData.label: i18n("Kick channels:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                Layout.minimumHeight: Kirigami.Units.gridUnit * 5
                wrapMode: TextEdit.WrapAnywhere
                placeholderText: i18n("e.g.\nxqc\ntrainwreckstv")
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                wrapMode: Text.WordWrap
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: i18n("One channel name per line (or separated by spaces/commas). Use the name from the channel URL, not the display name. Twitch channels show once you link below; Kick channels need a connected Kick account (set up below).")
            }

            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Appearance")
                Kirigami.FormData.isSection: true
            }

            QQC2.ComboBox {
                id: orientationCombo
                Kirigami.FormData.label: i18n("Expand:")
                model: [i18n("Horizontally"), i18n("Vertically")]
            }

            QQC2.ComboBox {
                id: hAlignCombo
                Kirigami.FormData.label: i18n("Horizontal align:")
                model: [i18n("Left"), i18n("Center"), i18n("Right")]
            }

            QQC2.ComboBox {
                id: vAlignCombo
                Kirigami.FormData.label: i18n("Vertical align:")
                model: [i18n("Top"), i18n("Center"), i18n("Bottom")]
            }

            QQC2.SpinBox {
                id: hoverSpin
                Kirigami.FormData.label: i18n("Show controls after:")
                from: 0
                to: 5000
                stepSize: 100
                textFromValue: function(value) {
                    return value === 0 ? i18n("Immediately")
                                       : i18n("%1 s", (value / 1000).toFixed(1));
                }
                valueFromText: function(text) { return Math.round(parseFloat(text) * 1000); }
            }

            QQC2.SpinBox {
                id: fontSpin
                Kirigami.FormData.label: i18n("Font size:")
                from: 8
                to: 48
                stepSize: 1
            }

            QQC2.ComboBox {
                id: fontFamilyCombo
                Kirigami.FormData.label: i18n("Font face:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                // First entry maps to "" (use the default UI font).
                model: [i18n("System default")].concat(root.fontFamilies)
                Component.onCompleted: {
                    var i = root.fontFamilies.indexOf(root.cfg_fontFamily);
                    currentIndex = (root.cfg_fontFamily && i >= 0) ? i + 1 : 0;
                }
                onActivated: root.cfg_fontFamily =
                    (currentIndex === 0 ? "" : root.fontFamilies[currentIndex - 1])
            }

            KQControls.ColorButton {
                id: colorButton
                Kirigami.FormData.label: i18n("Font color:")
                property bool ready: false
                dialogTitle: i18n("Streamer name color")
                Component.onCompleted: {
                    color = root.cfg_fontColor ? root.cfg_fontColor : Kirigami.Theme.textColor;
                    ready = true;
                }
                onColorChanged: if (ready) root.cfg_fontColor = color.toString()
            }

            QQC2.Button {
                Kirigami.FormData.label: i18n("")
                text: i18n("Use theme default color")
                icon.name: "edit-clear"
                visible: root.cfg_fontColor.length > 0
                onClicked: {
                    root.cfg_fontColor = "";
                    colorButton.color = Kirigami.Theme.textColor;
                }
            }

            QQC2.SpinBox {
                id: pollSpin
                Kirigami.FormData.label: i18n("Check every:")
                from: 30
                to: 3600
                stepSize: 30
                textFromValue: function(value) { return i18n("%1 seconds", value); }
                valueFromText: function(text) { return parseInt(text); }
            }

            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Resume after sleep")
                Kirigami.FormData.isSection: true
            }

            // Checkbox plus an inline "What is this?" link; the long explanation
            // lives in the link's hover tooltip instead of always taking up space.
            RowLayout {
                Kirigami.FormData.label: i18n("Faster recovery:")
                spacing: Kirigami.Units.largeSpacing

                QQC2.CheckBox {
                    id: curlResumeCheck
                    text: i18n("Refresh through an external curl process")
                }

                QQC2.Label {
                    id: curlHelpLink
                    text: i18n("What is this?")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.underline: curlHelpArea.containsMouse
                    color: Kirigami.Theme.linkColor

                    MouseArea {
                        id: curlHelpArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }

                    QQC2.ToolTip {
                        id: curlHelpTip
                        visible: curlHelpArea.containsMouse
                        delay: Kirigami.Units.toolTipDelay
                        // Fixed width so the multi-paragraph text wraps instead of
                        // stretching into one giant line.
                        implicitWidth: Kirigami.Units.gridUnit * 24
                        text: i18n("When the computer wakes from sleep, the network connection the widget had before sleeping is dead, but the desktop keeps reusing it — so the widget can keep showing a streamer as live (or offline) for up to ~15 minutes, until the system finally drops the stale connection.\n\nTurn this on to fetch stream status through a separate curl program instead. curl opens a brand-new connection each time, so the widget corrects itself within seconds of waking.\n\nSecurity note: with this on, the Twitch access token is passed to curl on its command line, where it is briefly visible to other user accounts on this computer (via /proc) for the moment each check runs. The token only reads public live-stream status, and your Kick Client Secret is never sent this way. On a single-user computer the risk is minimal.\n\nLeave it off (the default) and the widget uses its built-in connection and simply self-corrects within ~15 minutes after waking. Requires curl to be installed; if it isn't found, the widget falls back to the built-in behavior automatically.")
                        contentItem: QQC2.Label {
                            text: curlHelpTip.text
                            wrapMode: Text.WordWrap
                            font: Kirigami.Theme.smallFont
                            width: curlHelpTip.availableWidth
                        }
                    }
                }
            }
        }

        // Border / background around the whole widget.
        FrameSettings {
            id: widgetFrame
            Layout.fillWidth: true
            title: i18n("Widget border / background")
        }

        // Border / background around each live-streamer entry.
        FrameSettings {
            id: chipFrame
            Layout.fillWidth: true
            title: i18n("Per-streamer border / background")
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Account")
                Kirigami.FormData.isSection: true
            }

            QQC2.Button {
                Kirigami.FormData.label: i18n("Twitch:")
                // Reads the live, always-current state; updates the instant the
                // widget links/unlinks, even while this dialog stays open.
                text: Plasmoid.configuration.linked
                    ? i18n("Unlink Twitch account")
                    : i18n("Link Twitch account")
                icon.name: Plasmoid.configuration.linked ? "system-switch-user" : "link"
                // Acts immediately (no Apply): write the command flag straight to
                // the live config; the widget consumes and resets it at once.
                onClicked: {
                    if (Plasmoid.configuration.linked) {
                        Plasmoid.configuration.unlinkRequested = true;
                    } else {
                        Plasmoid.configuration.linkRequested = true;
                    }
                    Plasmoid.configuration.writeConfig();
                }
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                wrapMode: Text.WordWrap
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: Plasmoid.configuration.linked
                    ? i18n("Unlinking clears the saved Twitch authorization. You can re-link any time.")
                    : i18n("Links your Twitch account; approve the request in the browser window that opens.")
            }

            // ----------------------------------------------------------------
            // Kick: unlike Twitch, Kick has no shippable public client, so each
            // user registers their own app and pastes its Client ID + Secret.
            // These are written straight to the live config by the Connect
            // button (not via cfg_ aliases), mirroring how the tokens are kept
            // out of the Apply cycle.
            // ----------------------------------------------------------------
            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Kick")
                Kirigami.FormData.isSection: true
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.WordWrap
                visible: !Plasmoid.configuration.kickLinked
                text: i18n("Kick needs its own free app, which you create once:\n\n1. Click “Open Kick developer settings” below and sign in.\n2. Create a new app, using the recommended name and Redirect URI below (use Copy, then paste). The name has no spaces and a random suffix because Kick app names must be unique. The Redirect URI is only needed if Kick asks for one — the widget never uses it.\n3. Copy the app's Client ID and Client Secret into the fields below.\n4. Click “Connect Kick account”.")
            }

            QQC2.Button {
                Kirigami.FormData.label: i18n("Register:")
                visible: !Plasmoid.configuration.kickLinked
                text: i18n("Open Kick developer settings")
                icon.name: "internet-services"
                onClicked: Qt.openUrlExternally("https://kick.com/settings/developer")
            }

            // Recommended values for Kick's app form, shown read-only with a Copy
            // button so they can be pasted into Kick without retyping. (We can't
            // pre-fill the Client ID/Secret — Kick generates those per app.)
            RowLayout {
                Kirigami.FormData.label: i18n("App name (must be unique):")
                visible: !Plasmoid.configuration.kickLinked
                QQC2.TextField {
                    id: kickAppNameField
                    readOnly: true
                    // No spaces, and unique on Kick → fixed prefix + random hex.
                    // Pure hex (no separator) keeps it safely alphanumeric.
                    Component.onCompleted: text = "kdewidget" + root.randomHex(32)
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                }
                QQC2.Button {
                    text: i18n("Copy")
                    icon.name: "edit-copy"
                    onClicked: { kickAppNameField.selectAll(); kickAppNameField.copy(); kickAppNameField.deselect(); }
                }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Redirect URI:")
                visible: !Plasmoid.configuration.kickLinked
                QQC2.TextField {
                    id: kickRedirectField
                    readOnly: true
                    text: "http://localhost"
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                }
                QQC2.Button {
                    text: i18n("Copy")
                    icon.name: "edit-copy"
                    onClicked: { kickRedirectField.selectAll(); kickRedirectField.copy(); kickRedirectField.deselect(); }
                }
            }

            QQC2.TextField {
                id: kickIdField
                Kirigami.FormData.label: i18n("Client ID:")
                visible: !Plasmoid.configuration.kickLinked
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                // Seed from the live config so a half-entered value survives a
                // reopen; the field — not a cfg_ alias — is the source of truth.
                Component.onCompleted: text = Plasmoid.configuration.kickClientId
            }

            QQC2.TextField {
                id: kickSecretField
                Kirigami.FormData.label: i18n("Client Secret:")
                visible: !Plasmoid.configuration.kickLinked
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                echoMode: TextInput.Password
                Component.onCompleted: text = Plasmoid.configuration.kickClientSecret
            }

            QQC2.Button {
                Kirigami.FormData.label: i18n("Kick:")
                // Live state, like the Twitch button: flips the instant the
                // widget validates or drops the credentials.
                text: Plasmoid.configuration.kickLinked
                    ? i18n("Disconnect Kick account")
                    : i18n("Connect Kick account")
                icon.name: Plasmoid.configuration.kickLinked ? "system-switch-user" : "link"
                enabled: Plasmoid.configuration.kickLinked
                    || (kickIdField.text.trim().length > 0 && kickSecretField.text.trim().length > 0)
                onClicked: {
                    if (Plasmoid.configuration.kickLinked) {
                        Plasmoid.configuration.kickDisconnectRequested = true;
                        Plasmoid.configuration.writeConfig();
                        kickIdField.text = "";
                        kickSecretField.text = "";
                    } else {
                        // Save the credentials, then ask the widget to validate
                        // them by minting an app token right away.
                        Plasmoid.configuration.kickClientId = kickIdField.text.trim();
                        Plasmoid.configuration.kickClientSecret = kickSecretField.text.trim();
                        Plasmoid.configuration.kickConnectRequested = true;
                        Plasmoid.configuration.writeConfig();
                    }
                }
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.WordWrap
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: Plasmoid.configuration.kickLinked
                    ? i18n("Connected. Your Client ID and Secret are stored on this computer and used only to read public “who's live” data. Disconnecting removes them.")
                    : i18n("The Client Secret is stored locally on this computer. The widget reads only public live-stream status — it can't post or change anything on your account.")
            }
        }
    }
}
