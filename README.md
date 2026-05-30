# Twitch Live — KDE Plasma 6 widget

A tiny overlay widget for KDE Plasma 6 (Wayland/X11) that watches a list of
Twitch channels and shows which ones are **live right now**. Click a name to
open the channel in your browser.

## Features

- Monitors any number of channels via the official Twitch **Helix API**
- **No client secret** — uses the OAuth **Device Code flow** (a public client),
  so the widget is safe to publish. Users link with a one-time browser approval.
- Click a live streamer to open `https://twitch.tv/<channel>`
- Options: **font size**, **horizontal or vertical expansion**, and the
  **channels** to monitor
- Configurable poll interval (default 60 s)
- Panel mode shows an icon with a live-count badge; desktop mode shows the list

## How auth works (and why it's publish-safe)

Twitch requires a **Client ID** on every API call, so *someone* registers one
app — but only the **publisher**, once. End users never register anything.

This widget uses the **Device Code Grant flow**:

1. The widget asks Twitch for a short code.
2. You approve it in a browser (logging into *your own* Twitch account).
3. The widget gets a user token + refresh token. The refresh token is
   one-time-use and renews automatically **without any client secret** (public
   clients are allowed to refresh secret-free). It expires after ~30 days idle;
   open the widget within any 30-day window and it keeps working.

Because **no secret is ever shipped**, the source is safe to publish. The only
embedded value is the Client ID, which is public by design.

## 1. Register the app (publisher, one time, ~2 min)

1. Go to <https://dev.twitch.tv/console/apps> and log in.
2. **Register Your Application**:
   - **Name**: anything (e.g. `my-live-widget`)
   - **OAuth Redirect URLs**: `http://localhost`
   - **Category**: *Application Integration*
   - **Client Type**: **Public**  ← important; no secret is generated
3. Copy the **Client ID**.

To distribute the widget to others, hardcode that Client ID in
`contents/ui/main.qml`:

```qml
readonly property string embeddedClientId: "your_client_id_here"
```

(and you can then remove the Client ID field from the settings form). For your
own use you can skip that and just paste the Client ID into the widget's
settings instead.

## 2. Install

```sh
./install.sh
```

Installs into `~/.local/share/plasma/plasmoids/com.kevin.twitchlive` via
`kpackagetool6`. Then **Add Widgets… → "Twitch Live"** and drop it on your
desktop or panel. If it doesn't appear (or you upgraded), restart the shell:

```sh
kquitapp6 plasmashell && (kstart plasmashell >/dev/null 2>&1 &)
```

## 3. Configure & link

End users never enter a Client ID — it's baked into the widget. They just:

1. Click **Link Twitch account** in the widget → approve on the Twitch page that
   opens (or go to `twitch.tv/activate` and type the code shown).
2. Right-click → **Configure Twitch Live…** to set the **channels** to monitor
   (one login per line; use the name from the channel URL, e.g. `shroud`), and
   pick **horizontal/vertical** expansion and a **font size**.

After linking it polls automatically and re-checks immediately when you change
channels.

## Notes & limitations

- **No secret on disk.** Only the access/refresh tokens and the public Client ID
  are stored in the plasmoid config
  (`~/.config/plasma-org.kde.plasma.desktop-appletsrc`). The tokens grant only
  public read access (who's live) — no posting, no stream key, no account
  settings. Revoke anytime at <https://www.twitch.tv/settings/connections>.
- **Shared rate limit.** All users of a published build share the app's
  per-Client-ID Helix rate budget (~800 points/min). Fine for live polling.
- **Wayland always-on-top.** A desktop plasmoid sits on the desktop layer. For
  a floating-above-windows feel, use panel mode (with auto-hide) or a KWin
  window rule; Wayland restricts true overlays.
- Twitch's `/streams` endpoint only returns channels that are currently live,
  and accepts up to 100 logins per request.

## Uninstall

```sh
kpackagetool6 --type Plasma/Applet --remove com.kevin.twitchlive
```

## Files

```
package/
  metadata.json                 plasmoid manifest
  contents/
    config/main.xml             config schema (+ token storage)
    config/config.qml           settings categories
    config/configGeneral.qml    settings form
    ui/main.qml                 widget + device-flow auth + Twitch polling
```
