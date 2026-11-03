# ReDash360

Turn an old laptop or PC into a retro console. ReDash360 is an Xbox 360-style
desktop shell for Linux, made with Qt 6 and QML. Like SteamOS's Gaming Mode,
it's what you sign in to: a login screen like the 360's Sign In, then the
dashboard as your desktop, for your games and emulators and for everyday
things like browsing, music and videos. When you need your normal desktop for
something, Exit to Desktop takes you there. It's made for a controller, and
works with a keyboard and mouse too.

I made ReDash360 to give old computers a second life: put it on a laptop or
PC that isn't getting used anymore, plug in a controller, and it's a console
for gaming and everyday use.

ReDash360 is a fan project. It isn't made by or connected to Microsoft, and it
comes with none of the 360's artwork, sounds or logos: its icons are drawn in
code, app icons come from the apps you have, and you add your own pictures and
sounds.

## What's in it

- **A login screen** like the 360's Sign In: each profile with its avatar and
  gamer picture, and the on-screen keyboard for passwords.
- **The dashboard as your desktop**, on top of Hyprland or KDE Plasma.
- **The 360's tabs**: search, home, social, games, apps and settings.
- **Your games** from Steam, Heroic and Faugus, with four slots for the ones
  you play most, your recent games, and Steam achievements.
- **Your apps**, and Get for the ones you don't have yet (through Discover or
  GNOME Software).
- **Add-ons**: emulators, launchers and other apps for gaming.
- **The Guide**, over the dashboard or over a game. On Hyprland it can also
  pause and close the game you're in.
- **Your profile**: gamertag, gamer picture and an animated avatar.
- **News** about your Steam games, and from a gaming news site.
- **Discord** on the social tab.

## Controls

| Controller         | Keyboard   | Does                                   |
|--------------------|------------|----------------------------------------|
| D-pad / left stick | Arrow keys | Move                                   |
| A                  | Enter      | Select                                 |
| B                  | Esc        | Back                                   |
| X, Y               | X, Y       | What the hints at the bottom say       |
| LB / RB            | Q / E      | Previous / next tab                    |
| Guide              | Home       | The Guide                              |
| Start              | Menu       | Done, on the on-screen keyboard        |

## Install

### Arch Linux and CachyOS

```sh
git clone https://github.com/KevinKoortzen/ReDash360.git
cd ReDash360/packaging/arch/redash360-git
makepkg -si
systemctl --user daemon-reload
```

This builds the latest commit from GitHub and installs the dashboard, the
sessions and the login screen, and makes it SDDM's login screen. Run
`makepkg -si` in the same folder again to update.

### Other Linux

You need SDDM, Qt 6.10 or newer (base, declarative, multimedia and SVG), SDL2,
CMake, and layer-shell-qt for the Guide to show over games on Wayland. Install
into `/usr`, where SDDM and the sessions are looked for:

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
systemctl --user daemon-reload
```

To remove it again: `sudo xargs rm < build/install_manifest.txt`

## Using it

Sign out, and you're at ReDash360's login screen. Press X until it says the
session you want, pick your profile and press A:

- **ReDash360 (Hyprland)**: your own Hyprland setup, with the dashboard on top.
  Needs uwsm.
- **ReDash360 (Plasma)**: KDE Plasma without its desktop, panels and splash
  screen, with the dashboard instead. There are no notification pop-ups in
  this one: they come from Plasma's desktop.

The login screen remembers the session for next time.

**Exit to Desktop** (Guide > Settings > Turn Off Console > Exit to Desktop)
takes you to your normal desktop: on Hyprland it's already there under the
dashboard, and on Plasma it brings Plasma's desktop up. To go back, start
ReDash360 from the app menu.

**Sign Out** (on the social tab, or X in the Guide) takes you back to the login
screen. If the dashboard crashes in a session it comes straight back;
`journalctl --user -b -u redash360` shows what happened.

You can also run ReDash360 as an app in your normal desktop session. Settings >
Preferences > Start Automatically opens it every time you sign in. Only one
dashboard runs at a time: starting it again brings the running one to the
front, and `appReDash360 --replace` replaces it instead.

## Your pictures and sounds

Put your own in `~/.local/share/ReDash360`:

| Folder        | What                                                         |
|---------------|--------------------------------------------------------------|
| `backgrounds` | Pictures for behind the dashboard (Settings > Preferences)   |
| `gamerpics`   | Gamer pictures: PNG, JPG, WebP or GIF                        |
| `avatars`     | Avatars: an animated GIF works best                          |
| `sounds`      | `move.wav`, `tab.wav`, `select.wav`, `back.wav`, `guide-open.wav` and `guide-close.wav` |

A missing sound is just silence, so you can add them one at a time. Settings
are kept in `~/.config/ReDash360/ReDash360.conf`.

## The login screen

ReDash360's login screen is an SDDM theme, and installing ReDash360 switches
SDDM to it with `/etc/sddm.conf.d/zz-redash360.conf`. A `Current=` line in
`/etc/sddm.conf` itself wins over that, so if you have one, change it to
`Current=redash360`.

To use another login screen again, change `Current=redash360` in
`/etc/sddm.conf.d/zz-redash360.conf` to that theme's folder name in
`/usr/share/sddm/themes` (`breeze` is Plasma's). Your change stays when
ReDash360 updates.

To try the login screen in a window first:

```sh
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/redash360
```

Each profile shows the gamer picture and avatar you picked in ReDash360. For
that, ReDash360 copies them to `~/.redash360` each time it starts, and lets the
login screen (which runs as the `sddm` user) into your home folder with
`setfacl -m u:sddm:x ~`. That lets `sddm` open files there that everyone may
read, if it knows their names, but not list what's in your home folder.

## Windows

The dashboard also runs on Windows, as an app. Open `CMakeLists.txt` in Qt
Creator with a Qt 6.10 MinGW kit. It looks for SDL2 in
`C:\SDL2\x86_64-w64-mingw32`: that folder comes from SDL2's MinGW development
download. Put `SDL2.dll` next to `appReDash360.exe`. The login screen and the
sessions are Linux only.

## License

ReDash360 is under the [PolyForm Strict License 1.0.0](LICENSE.md). You can
install and use it for free for anything that isn't commercial, but you may not
sell it, share copies of it, or make changed versions of it. If you'd like to
do something the license doesn't allow, ask me.
