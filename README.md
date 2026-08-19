# model o control

glorious never made proper macOS software for my original wired Model O. i was tired of needing Windows just to change the DPI, lighting or debounce, so i made the app i wanted.

it is a native SwiftUI app that talks directly to the mouse's onboard HID reports. it does not replace the normal macOS mouse driver, need an account, run a cloud service or sit there constantly writing to the mouse.

this is for the original wired Model O / O- with USB ID `258A:0036`. it is not for the wireless models, Model O 2 or every mouse Glorious has made since.

## what it does

- reads and writes all six DPI stages, their indicator colours and the active stage
- controls 125 / 250 / 500 / 1000 Hz polling, 4-16 ms debounce and 2 / 3 mm lift-off distance
- has the V1 lighting effects, 18 quick looks, custom colours and locally saved lighting profiles
- remaps all six physical buttons to mouse, scroll, DPI, media or macro actions
- programs two onboard macro banks with click and keyboard shortcut presets
- saves whole-device profiles and can stage a profile when a chosen app opens
- puts connection state, current DPI and favourite profiles in the menu bar
- includes a live mouse tester, movement graph, click timing, button counts and scroll stats
- includes read-only diagnostics, a raw report viewer and copyable diagnostic reports
- backs up the untouched configuration and button map before every apply or restore
- shows the exact before/after changes and reads the mouse back after a write

## the safety bit

normal settings and button assignments are backed up before they are written, then checked against what the mouse actually returned. unknown bytes in the reports are preserved instead of being guessed at.

the macro protocol is the one exception. this V1 firmware has a command to write macro banks but no matching command to read them, so an old macro cannot be backed up or verified. the app says this clearly and asks again before it replaces a bank.

per-app rules only stage a draft. they never silently write to onboard memory when an app opens.

## macOS permission

the configuration interface identifies itself as a keyboard-capable HID device, so macOS requires Privacy & Security -> Input Monitoring permission. Model O Control does not record keystrokes. it matches USB `258A:0036` and uses vendor feature reports to talk to the mouse.

after enabling the permission, quit and reopen the app once.

## build it

you need macOS 14 or newer and Swift 6 / a current Xcode toolchain.

```sh
swift test
./scripts/build-app.sh
```

the finished ad-hoc signed app is written to `outputs/Model O Control.app`.

## protocol work

this is an independent implementation built from testing my own mouse and public reverse-engineering work:

- [enkore/gloriousctl](https://github.com/enkore/gloriousctl) - EUPL-1.2
- [sammko/gloryctl](https://github.com/sammko/gloryctl) - MIT

Glorious and Model O are trademarks of their owner. this project is not affiliated with Glorious LLC.
