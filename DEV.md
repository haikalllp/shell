# Dev Guide — caelestia-shell

## Prerequisites

See [README.md](README.md) for the full dependency list. Key build deps:

- cmake, ninja
- qt6-base, qt6-declarative
- quickshell-git (must be git version, not latest tagged)

Runtime deps include ddcutil, brightnessctl, libcava, libpipewire, aubio, libqalculate, fish, networkmanager, etc.

## Build

The C++ plugin must be built and installed for the shell to work. This only installs the native plugin to system paths — it does **not** touch `~/.config/quickshell/`.

```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
```

Rebuild after changing anything in `plugin/` or `extras/`.

## Run

Always run from the repo root using `qs -p .` — this tells quickshell to load `shell.qml` directly from this directory, bypassing any installed config in `~/.config/quickshell/`.

```sh
# Run in foreground
qs -p .

# Run as daemon (detach from terminal)
qs -p . -d

# With verbose logging
qs -p . -v                # INFO level internal logs
qs -p . -vv               # DEBUG level internal logs

# QML debugger (attach with Qt Creator or qmldebug)
qs -p . --debug 1234 --waitfordebug
```

`shell.qml` has `settings.watchFiles: true` so QML changes reload live on save. C++ changes in `plugin/` require a rebuild + restart.

### Managing instances

```sh
qs list                   # list running instances
qs kill                   # kill running instances
qs log                    # tail logs
```

## Configuration

Config lives in `~/.config/caelestia/` (not in the repo):

| File | Purpose |
|---|---|
| `shell.json` | Main config (bar, launcher, notifications, services, etc.) |
| `shell-tokens.json` | Internal design tokens (rounding, spacing, font sizes, animation curves) |
| `monitors/<name>/shell.json` | Per-monitor config overrides |
| `monitors/<name>/shell-tokens.json` | Per-monitor token overrides |

`shell.json` is not created by default — create it manually and only add options you want to change. See the README for the full example config with all available options.

## Project structure

```
shell.qml              Entry point — loads all modules

modules/               UI feature modules
  bar/                   Status bar (workspaces, tray, clock, status icons)
  launcher/              App/action launcher with fuzzy search
  dashboard/             Info panel (media, weather, performance, lyrics)
  notifications/         Notification popups
  sidebar/               Notification history sidebar
  osd/                   On-screen display (volume, brightness)
  lock/                  Lock screen with PAM auth
  controlcenter/         Full settings UI
  drawers/               Edge-swipe drawer system
  session/               Power dialog (logout, shutdown, reboot, hibernate)
  background/            Wallpaper, desktop clock, audio visualiser
  areapicker/            Screen area picker (screenshots)
  utilities/             Quick toggles and toast notifications
  windowinfo/            Window info tooltip/preview
  BatteryMonitor.qml     Battery warning notifications
  ConfigToasts.qml       Config reload toast notifications
  Shortcuts.qml          Hyprland D-Bus global shortcut bindings
  IdleMonitors.qml       Idle timeout handling

components/            Reusable QML components
  controls/              Buttons, inputs, sliders, switches, menus, etc.
  containers/            StyledFlickable, StyledListView, StyledWindow
  effects/               ColouredIcon, Colouriser, Elevation, InnerBorder, OpacityMask
  images/                CachingIconImage, CachingImage
  filedialog/            Custom file dialog
  misc/                  CustomShortcut, Ref
  MaterialIcon.qml       Material Symbols icon font renderer
  Anim.qml, CAnim.qml    Animation helpers
  StyledRect.qml, etc.   Styled base primitives

services/              QML singleton data/system services
  Audio.qml              PipeWire/PulseAudio volume control
  Brightness.qml         Screen brightness
  Colours.qml            Colour scheme engine
  GameMode.qml           Game mode toggle
  Hypr.qml               Hyprland IPC
  Network.qml            Network status/management
  Players.qml            MPRIS media player tracking
  Notifs.qml             Notification daemon
  SystemUsage.qml        CPU/RAM/GPU/disk stats
  Weather.qml            Weather data
  Wallpapers.qml         Wallpaper listing/switching
  VPN.qml                VPN management
  Screens.qml            Monitor management
  Visibilities.qml       UI panel visibility state

utils/                 Utility modules
  Icons.qml              Icon name constants
  Paths.qml              File path resolution
  Searcher.qml           Search/filter logic
  Strings.qml            String formatting
  scripts/               JS helpers (fuzzysort, fzf, lrcparser)

plugin/                C++ QML plugin (native backend)
  src/Caelestia/
    appdb.cpp            Application database (launcher indexing)
    cutils.cpp           General C++ utilities
    imageanalyser.cpp    Image colour analysis (dynamic schemes)
    qalculator.cpp       libqalculate wrapper (calculator)
    requests.cpp         HTTP requests (weather, lyrics)
    Config/              shell.json config parsing
    Services/            Native background services
    Models/              Data models for QML views
    Components/          QML type registrations

extras/                Build extras (version info library)
assets/                Static resources (SVGs, GIFs, PNGs, shaders, PAM configs)
nix/                   Nix packaging & Home Manager module
scripts/               Dev tooling (QML lint script)
```

## Debugging

All commands use `-p .` to target the local fork instance.

```sh
# Verbose logging levels
qs -p . -v              # INFO level internal logs
qs -p . -vv             # DEBUG level internal logs

# Log filtering (Qt log rules format)
qs -p . --log-rules "qt.qml.*=true"

# View logs from a running instance
qs log

# IPC — always use -p . to target the local fork
qs ipc -p . show                                    # list all IPC targets/functions
qs ipc -p . call lock lock                          # lock the screen
qs ipc -p . call lock unlock                        # unlock the screen
qs ipc -p . call lock isLocked                      # check lock state
qs ipc -p . call mpris playPause                    # toggle play/pause
qs ipc -p . call mpris next                         # next track
qs ipc -p . call mpris previous                     # previous track
qs ipc -p . call mpris getActive trackTitle         # get current track title
qs ipc -p . call mpris list                         # list media players
qs ipc -p . call drawers toggle sidebar             # toggle a drawer
qs ipc -p . call drawers list                       # list available drawers
qs ipc -p . call wallpaper set /path/to/img         # set wallpaper
qs ipc -p . call wallpaper get                      # get current wallpaper
qs ipc -p . call wallpaper list                     # list wallpapers
qs ipc -p . call notifs clear                       # clear notifications
qs ipc -p . call picker open                        # open colour picker
qs ipc -p . call picker openFreeze                  # open frozen colour picker

# Listen for IPC signals
qs ipc -p . listen

# Target by PID instead (if multiple instances running)
qs ipc --pid <PID> call lock lock
```

## Architecture

```
shell.qml (entry point)
  |
  +-- modules/       Feature UI (bar, launcher, lock, dashboard, etc.)
  |     |
  |     +-- components/   Shared reusable primitives
  |
  +-- services/      Data providers & system bridges
  +-- utils/         Pure utility code
  +-- plugin/        C++ native backend (image analysis, HTTP, calculator, app DB)
  +-- extras/        Build-time native library (version info)
  +-- assets/        Static resources (images, shaders, PAM configs)
```

Data flow: `services/` expose system data to QML → `modules/` consume it for UI → `components/` provide shared UI building blocks → `plugin/` handles performance-critical native operations.
