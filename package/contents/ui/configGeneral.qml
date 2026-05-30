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
    // (Client ID is baked into the widget; users just link from the widget.)
    property alias cfg_channels: channelsField.text
    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_fontSize: fontSpin.value
    property alias cfg_orientation: orientationCombo.currentIndex
    property alias cfg_hAlign: hAlignCombo.currentIndex
    property alias cfg_vAlign: vAlignCombo.currentIndex
    property alias cfg_hoverDelay: hoverSpin.value
    property string cfg_fontColor: ""
    property string cfg_fontFamily: ""

    // NOTE: linked / linkRequested / unlinkRequested are deliberately NOT exposed
    // as cfg_ properties. The shell only round-trips keys that have a matching
    // cfg_ property, so leaving them off means the Apply cycle never touches the
    // tokens. The Link/Unlink button instead writes Plasmoid.configuration
    // directly for an immediate, live effect.

    readonly property var fontFamilies: Qt.fontFamilies()

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Channels")
            Kirigami.FormData.isSection: true
        }

        QQC2.TextArea {
            id: channelsField
            Kirigami.FormData.label: i18n("Monitor:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            Layout.minimumHeight: Kirigami.Units.gridUnit * 6
            wrapMode: TextEdit.WrapAnywhere
            placeholderText: i18n("e.g.\nshroud\nxqc\nsummit1g")
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: i18n("One channel login per line (or separated by spaces/commas). Use the name from the channel URL, not the display name.")
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
    }
}
