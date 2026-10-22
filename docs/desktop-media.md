# Playback options and desktop media controls

The speed button beside the timeline opens **Audio & playback**:

- Audio tracks include language and embedded title, with a **No audio** option.
- Playback speed ranges from 0.25× to 3×. The selected rate is remembered across launches.
- Audio delay ranges from −2000 to +2000 milliseconds in 50 ms steps. Positive values play audio later; negative values play it earlier. The delay uses wall-clock milliseconds at any playback speed and resets when changing or reopening a file.

Delay is available for seekable local files with audio. Qt exposes no public signed A/V offset, so `PlaybackOptions` uses a second audio decoder for nonzero offsets. The primary decoder retains a silent audio clock; the shifted decoder follows playback state, track selection, rate, seeks, device, volume and mute. A 25 ms timer corrects drift over 100 ms. Zero delay releases the extra decoder and restores the normal output. This costs an additional decoder while enabled and is not a sample-accurate audio workstation synchronization mechanism. Backend errors restore normal playback and report the error.

Scroll vertically over the audio/video player or its volume control to change volume by 5% per mouse-wheel notch. High-resolution wheels and touchpads scale smaller deltas smoothly. Volume stays between 0% and 100%, increasing it unmutes playback, and fullscreen controls appear to show the change. Transcript, playlist and dialog scrolling keep their normal behavior; modified and horizontal wheel gestures do not adjust playback volume.

## MPRIS on Linux

MAPL registers `org.mpris.MediaPlayer2.mapl_player` on the session bus, exporting `/org/mpris/MediaPlayer2`. Additional instances use `.instance<pid>_<n>` names. The implementation uses the standard [MPRIS root](https://specifications.freedesktop.org/mpris/latest/Media_Player.html) and [player](https://specifications.freedesktop.org/mpris/latest/Player_Interface.html) interfaces.

Desktop widgets and compatible clients can play, pause, toggle, stop, navigate the playlist, seek, change volume and rate, open supported local media, raise the window and quit. The service reports title, artist and album when embedded metadata supplies them, cover art when available, duration, playback status and current capabilities. Positions, lengths and seek signals use MPRIS microseconds. Stale track IDs cannot seek a newly loaded file.

Navigation preserves whether playback was playing, paused or stopped. At playlist boundaries, capabilities reflect the playlist-loop toggle. Normal position updates are read through `Position`; discontinuous seeks emit `Seeked`. Other changes use `org.freedesktop.DBus.Properties.PropertiesChanged`. The optional MPRIS TrackList, Playlists, Shuffle and LoopStatus interfaces/properties are not advertised.

MPRIS commands pass through the same application logic as the UI. A file with a saved position still requires the Resume / Start from beginning choice. `OpenUri` accepts existing local files with supported audio/video extensions, and rejects remote URLs and directories. Without a session bus, local playback continues normally. No global key grab is installed: media-key routing depends on the desktop or client.

For example, with `playerctl` installed:

```sh
playerctl --player=mapl_player play-pause
playerctl --player=mapl_player next
playerctl --player=mapl_player position 30
playerctl --player=mapl_player rate 1.25
```

## Windows and floating desktops

MAPL identifies its Wayland window as `mapl-player`, matching `mapl-player.desktop`. Its panels stay centered inside the player, take keyboard focus and remain within the window when resized. Escape closes a dismissible panel before it exits fullscreen. Playback keyboard shortcuts wait until dialogs close. File choosers belong to the player as window-modal dialogs; their appearance follows the desktop's file chooser.

Floating is a compositor preference. In River Classic, add a **float** window rule for application ID **mapl-player** in River Control Center. For the current session, the equivalent command is:

```sh
riverctl rule-add -app-id mapl-player float
```

River applies floating rules to newly opened windows. Close and reopen the player after adding the rule. On other tiling desktops, use the same application ID in their window rules.

## Development and checks

The production sources are `PlaybackOptions`, `MprisService` and `MprisAdaptors`. Qt DBus is required alongside the existing Qt modules. The regression suite creates real multilingual media and tests actual audio timelines, rate, track switching and cleanup. MPRIS integration tests run under a private `dbus-run-session`, so they do not operate any desktop player belonging to the user. QML application tests disable desktop registration.
