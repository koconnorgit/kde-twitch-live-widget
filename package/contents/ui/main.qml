import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ------------------------------------------------------------------
    // Publisher config: hardcode your PUBLIC-client Client ID here for a
    // public release so end users never have to enter it. If left empty,
    // the value from the settings dialog (Plasmoid.configuration.clientId)
    // is used instead.
    // ------------------------------------------------------------------
    readonly property string embeddedClientId: "0voosrrcycnc46i7nldbgaqx5aeosj"
    readonly property string clientId: (root.embeddedClientId
        || Plasmoid.configuration.clientId || "").trim()

    // Currently live channels: [{ login, name, game, viewers, title }]
    property var liveStreams: []
    property string statusText: i18n("Loading…")
    property bool busy: false

    // OAuth / device-flow state
    // authState: "unlinked" | "linking" | "linked"
    property string authState: (Plasmoid.configuration.refreshToken
        || Plasmoid.configuration.cachedToken) ? "linked" : "unlinked"
    property string userCode: ""
    property string verificationUri: ""
    property string deviceCode: ""

    readonly property int orientation: Plasmoid.configuration.orientation // 0 = horizontal, 1 = vertical
    readonly property int fontSize: Plasmoid.configuration.fontSize
    readonly property string fontColor: Plasmoid.configuration.fontColor // "" = theme text color
    readonly property string fontFamily: Plasmoid.configuration.fontFamily // "" = default font
    readonly property int hAlign: Plasmoid.configuration.hAlign // 0 left, 1 center, 2 right
    readonly property int vAlign: Plasmoid.configuration.vAlign // 0 top, 1 center, 2 bottom
    readonly property int hoverDelay: Plasmoid.configuration.hoverDelay // ms before controls appear
    // Resolved colors used by the delegate
    readonly property color normalColor: fontColor ? fontColor : Kirigami.Theme.textColor
    readonly property color hoverColor: Kirigami.Theme.highlightedTextColor

    // No frame / panel behind the widget — just the content.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // Keep the settings-page mirror of link state in sync (display only).
    onAuthStateChanged: Plasmoid.configuration.linked = (authState === "linked")
    Component.onCompleted: Plasmoid.configuration.linked = (authState === "linked")

    toolTipMainText: i18n("Twitch Live")
    toolTipSubText: authState !== "linked"
        ? i18n("Not linked to Twitch")
        : (liveStreams.length > 0
            ? i18np("%1 channel live", "%1 channels live", liveStreams.length)
            : statusText)

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function channelList() {
        var raw = Plasmoid.configuration.channels || "";
        return raw.split(/[\s,]+/)
                  .map(function (s) { return s.trim().toLowerCase(); })
                  .filter(function (s) { return s.length > 0; });
    }

    function clearTokens() {
        Plasmoid.configuration.cachedToken = "";
        Plasmoid.configuration.refreshToken = "";
        Plasmoid.configuration.tokenExpiry = 0;
    }

    // ------------------------------------------------------------------
    // Device Code Grant flow (no client secret, public client)
    // ------------------------------------------------------------------
    function startDeviceAuth() {
        if (!clientId) {
            root.statusText = i18n("Set a Client ID in settings first");
            return;
        }
        root.authState = "linking";
        root.statusText = i18n("Requesting code from Twitch…");

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "https://id.twitch.tv/oauth2/device");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                var r = JSON.parse(xhr.responseText);
                root.deviceCode = r.device_code;
                root.userCode = r.user_code;
                root.verificationUri = r.verification_uri;
                devicePoll.interval = Math.max(5, (r.interval || 5)) * 1000;
                deviceExpiry.interval = Math.max(60, (r.expires_in || 1800)) * 1000;
                root.statusText = i18n("Waiting for you to approve on Twitch…");
                devicePoll.restart();
                deviceExpiry.restart();
                // Open the verification page (it has the code pre-filled).
                Qt.openUrlExternally(root.verificationUri);
            } else {
                root.authState = "unlinked";
                root.statusText = i18n("Could not start linking (%1)", xhr.status);
            }
        };
        // streams data is public, so no scopes are requested
        xhr.send("client_id=" + encodeURIComponent(clientId) + "&scopes=");
    }

    function pollDeviceToken() {
        if (root.authState !== "linking" || !root.deviceCode) return;

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "https://id.twitch.tv/oauth2/token");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                var r = JSON.parse(xhr.responseText);
                Plasmoid.configuration.cachedToken = r.access_token;
                Plasmoid.configuration.refreshToken = r.refresh_token || "";
                Plasmoid.configuration.tokenExpiry = Date.now() + (r.expires_in * 1000);
                devicePoll.stop();
                deviceExpiry.stop();
                root.deviceCode = "";
                root.userCode = "";
                root.authState = "linked";
                root.statusText = i18n("Linked! Checking streams…");
                root.checkStreams(false);
            } else {
                // 400 + authorization_pending is normal until the user approves;
                // keep polling. Anything else (e.g. expired) is handled by the
                // expiry timer / a fresh attempt.
            }
        };
        xhr.send("client_id=" + encodeURIComponent(clientId) +
                 "&scopes=" +
                 "&device_code=" + encodeURIComponent(root.deviceCode) +
                 "&grant_type=urn:ietf:params:oauth:grant-type:device_code");
    }

    Timer { // polls the token endpoint while linking
        id: devicePoll
        repeat: true
        onTriggered: root.pollDeviceToken()
    }

    Timer { // gives up if the user never approves
        id: deviceExpiry
        repeat: false
        onTriggered: {
            if (root.authState === "linking") {
                devicePoll.stop();
                root.authState = "unlinked";
                root.deviceCode = "";
                root.userCode = "";
                root.statusText = i18n("Code expired — try linking again");
            }
        }
    }

    function unlink() {
        devicePoll.stop();
        deviceExpiry.stop();
        clearTokens();
        root.liveStreams = [];
        root.authState = "unlinked";
        root.statusText = i18n("Not linked");
    }

    // ------------------------------------------------------------------
    // Token use + refresh (public client: refresh needs no secret)
    // ------------------------------------------------------------------
    function ensureToken(cb) {
        var now = Date.now();
        var tok = Plasmoid.configuration.cachedToken;
        var exp = Plasmoid.configuration.tokenExpiry;
        if (tok && exp > now + 60000) { // still valid (1 min safety margin)
            cb(tok);
            return;
        }

        var rt = Plasmoid.configuration.refreshToken;
        if (!rt) {
            root.authState = "unlinked";
            root.statusText = i18n("Link your Twitch account");
            return;
        }

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "https://id.twitch.tv/oauth2/token");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                var r = JSON.parse(xhr.responseText);
                Plasmoid.configuration.cachedToken = r.access_token;
                // refresh tokens are one-time-use — persist the new one
                if (r.refresh_token) Plasmoid.configuration.refreshToken = r.refresh_token;
                Plasmoid.configuration.tokenExpiry = Date.now() + (r.expires_in * 1000);
                root.authState = "linked";
                cb(r.access_token);
            } else {
                // refresh token revoked or 30-day-expired → require re-link
                clearTokens();
                root.authState = "unlinked";
                root.statusText = i18n("Session expired — please re-link");
            }
        };
        xhr.send("grant_type=refresh_token" +
                 "&refresh_token=" + encodeURIComponent(rt) +
                 "&client_id=" + encodeURIComponent(clientId));
    }

    function checkStreams(retry) {
        if (root.authState !== "linked") return;
        var chans = channelList();
        if (chans.length === 0) {
            root.liveStreams = [];
            root.statusText = i18n("No channels configured");
            return;
        }
        if (root.busy) return;
        root.busy = true;

        ensureToken(function (token) {
            // Helix /streams accepts up to 100 user_login params; only live channels are returned.
            var qs = chans.slice(0, 100).map(function (c) {
                return "user_login=" + encodeURIComponent(c);
            }).join("&");

            var xhr = new XMLHttpRequest();
            xhr.open("GET", "https://api.twitch.tv/helix/streams?" + qs);
            xhr.setRequestHeader("Client-Id", clientId);
            xhr.setRequestHeader("Authorization", "Bearer " + token);
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                root.busy = false;
                if (xhr.status === 200) {
                    var data = (JSON.parse(xhr.responseText).data) || [];
                    var arr = data.map(function (s) {
                        return {
                            login: s.user_login,
                            name: s.user_name,
                            game: s.game_name || "",
                            viewers: s.viewer_count || 0,
                            title: s.title || ""
                        };
                    });
                    arr.sort(function (a, b) { return b.viewers - a.viewers; });
                    root.liveStreams = arr;
                    root.statusText = arr.length ? "" : i18n("Nobody's live right now");
                } else if (xhr.status === 401 && !retry) {
                    // Access token rejected — drop it and refresh once.
                    Plasmoid.configuration.cachedToken = "";
                    Plasmoid.configuration.tokenExpiry = 0;
                    root.checkStreams(true);
                } else {
                    root.statusText = i18n("API error (%1)", xhr.status);
                }
            };
            xhr.send();
        });
    }

    Timer {
        id: pollTimer
        interval: Math.max(30, Plasmoid.configuration.pollInterval) * 1000
        running: root.authState === "linked"
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkStreams(false)
    }

    // Re-check immediately when channels change (while linked).
    Connections {
        target: Plasmoid.configuration
        function onChannelsChanged() { root.checkStreams(false); }
        // The settings Link/Unlink buttons set these flags; consume them here so
        // the config form never has to touch (and risk clobbering) the tokens.
        // Guards make these idempotent: re-applying the dialog (which keeps its
        // local flag set) is a harmless no-op instead of re-firing the flow.
        function onUnlinkRequestedChanged() {
            if (Plasmoid.configuration.unlinkRequested) {
                Plasmoid.configuration.unlinkRequested = false;
                if (root.authState !== "unlinked") root.unlink();
            }
        }
        function onLinkRequestedChanged() {
            if (Plasmoid.configuration.linkRequested) {
                Plasmoid.configuration.linkRequested = false;
                if (root.authState === "unlinked") root.startDeviceAuth();
            }
        }
    }

    // ------------------------------------------------------------------
    // Delegate for one live streamer (clickable chip)
    // ------------------------------------------------------------------
    Component {
        id: streamDelegate

        Rectangle {
            id: chip
            radius: Kirigami.Units.smallSpacing
            color: hover.hovered ? Kirigami.Theme.highlightColor : "transparent"
            implicitWidth: chipRow.implicitWidth + Kirigami.Units.largeSpacing
            implicitHeight: chipRow.implicitHeight + Kirigami.Units.smallSpacing
            Layout.fillWidth: root.orientation === 1

            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Rectangle { // "live" dot
                    Layout.preferredWidth: Math.round(root.fontSize * 0.5)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: "#e62117"
                }

                ColumnLayout {
                    spacing: 0
                    PC3.Label {
                        text: modelData.name
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily ? root.fontFamily : Kirigami.Theme.defaultFont.family
                        // A subtle shadow-ish contrast helps on a frameless/transparent widget
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                        color: hover.hovered ? root.hoverColor : root.normalColor
                    }
                    PC3.Label { // extra detail only makes sense in vertical mode
                        visible: root.orientation === 1 && modelData.game.length > 0
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.game + " • " +
                              i18np("%1 viewer", "%1 viewers", modelData.viewers)
                        font.pixelSize: Math.max(8, Math.round(root.fontSize * 0.72))
                        font.family: root.fontFamily ? root.fontFamily : Kirigami.Theme.defaultFont.family
                        opacity: 0.85
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                        color: hover.hovered ? root.hoverColor : root.normalColor
                    }
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Qt.openUrlExternally("https://twitch.tv/" + modelData.login)
            }
        }
    }

    // ------------------------------------------------------------------
    // Compact (panel) representation
    // ------------------------------------------------------------------
    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: "live-stream"
            active: parent.containsMouse

            Rectangle { // count badge
                visible: root.authState === "linked" && root.liveStreams.length > 0
                anchors { right: parent.right; top: parent.top }
                width: Math.max(height, badge.implicitWidth + 4)
                height: Math.round(parent.height * 0.5)
                radius: height / 2
                color: "#e62117"
                PC3.Label {
                    id: badge
                    anchors.centerIn: parent
                    text: root.liveStreams.length
                    color: "white"
                    font.pixelSize: Math.round(parent.height * 0.7)
                    font.bold: true
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Full representation — frameless & transparent.
    //   • linked + live   → just the clickable streamer names
    //   • linked + none   → nothing (a faint hint appears on hover)
    //   • unlinked/linking → the link/approve UI
    //   • hovering         → small refresh/relink/configure controls appear
    // ------------------------------------------------------------------
    fullRepresentation: Item {
        id: rep
        // Size to the content so a horizontal layout can be as thin as the text
        // (lets you align it flush to a screen edge). No tall minimum height.
        Layout.minimumWidth: Kirigami.Units.gridUnit * 3
        Layout.minimumHeight: contentCol.implicitHeight
        implicitWidth: contentCol.implicitWidth
        implicitHeight: contentCol.implicitHeight

        // Controls appear only after the pointer dwells for hoverDelay ms,
        // so sweeping the cursor across a wide strip doesn't flash them.
        property bool controlsShown: false
        HoverHandler {
            id: repHover
            onHoveredChanged: {
                if (hovered) {
                    if (root.hoverDelay <= 0) rep.controlsShown = true;
                    else hoverTimer.restart();
                } else {
                    hoverTimer.stop();
                    rep.controlsShown = false;
                }
            }
        }
        Timer {
            id: hoverTimer
            interval: root.hoverDelay
            repeat: false
            onTriggered: rep.controlsShown = true
        }

        ColumnLayout {
            id: contentCol
            // Pin the content block to the chosen edge/corner of the widget box,
            // so text can hug a side regardless of the box's forced size.
            // (Positioned with x/y to avoid conflicting-anchor combinations.)
            x: root.hAlign === 0 ? 0
               : root.hAlign === 2 ? (parent.width - width)
               : (parent.width - width) / 2
            y: root.vAlign === 0 ? 0
               : root.vAlign === 2 ? (parent.height - height)
               : (parent.height - height) / 2
            spacing: Kirigami.Units.smallSpacing

            // ---- not linked: prompt to link ----
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.authState === "unlinked"
                spacing: Kirigami.Units.smallSpacing

                PC3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0.85
                    text: root.clientId
                        ? i18n("Link your Twitch account to start.")
                        : i18n("Set a Client ID in settings, then link.")
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.smallSpacing
                    PC3.Button {
                        icon.name: "link"
                        text: i18n("Link Twitch account")
                        enabled: root.clientId.length > 0
                        onClicked: root.startDeviceAuth()
                    }
                    PC3.ToolButton {
                        icon.name: "configure"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: Plasmoid.internalAction("configure").trigger()
                        QQC2.ToolTip.text: i18n("Configure…")
                        QQC2.ToolTip.visible: hovered
                    }
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: root.statusText.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                    text: root.statusText
                }
            }

            // ---- linking: show the code + open-browser ----
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.authState === "linking"
                spacing: Kirigami.Units.smallSpacing

                PC3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: i18n("Approve on the Twitch page that opened, or go to twitch.tv/activate and enter:")
                }
                PC3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.userCode.length > 0
                    text: root.userCode
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.round(root.fontSize * 1.6)
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.smallSpacing
                    PC3.Button {
                        icon.name: "internet-services"
                        text: i18n("Open Twitch")
                        visible: root.verificationUri.length > 0
                        onClicked: Qt.openUrlExternally(root.verificationUri)
                    }
                    PC3.Button {
                        icon.name: "dialog-cancel"
                        text: i18n("Cancel")
                        onClicked: root.unlink()
                    }
                }
                PC3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                    text: root.statusText
                }
            }

            // ---- linked + live: the clickable names ----
            GridLayout {
                Layout.fillWidth: true
                visible: root.authState === "linked" && root.liveStreams.length > 0
                // Horizontal: one row of N chips. Vertical: one column.
                columns: root.orientation === 0 ? Math.max(1, root.liveStreams.length) : 1
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.liveStreams
                    delegate: streamDelegate
                }
            }

            // ---- linked + nothing live: faint hint, only while hovered ----
            PC3.Label {
                Layout.fillWidth: true
                visible: root.authState === "linked" && root.liveStreams.length === 0 && rep.controlsShown
                text: root.statusText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.5
                font: Kirigami.Theme.smallFont
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.6)
            }
        }

        // ---- floating hover controls (top-right), only when linked ----
        RowLayout {
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0
            visible: root.authState === "linked" && rep.controlsShown
            opacity: 0.9

            PC3.ToolButton {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                enabled: !root.busy
                onClicked: root.checkStreams(false)
                QQC2.ToolTip.text: i18n("Refresh now")
                QQC2.ToolTip.visible: hovered
            }
            PC3.ToolButton {
                icon.name: "configure"
                display: QQC2.AbstractButton.IconOnly
                onClicked: Plasmoid.internalAction("configure").trigger()
                QQC2.ToolTip.text: i18n("Configure…")
                QQC2.ToolTip.visible: hovered
            }
        }
    }
}
