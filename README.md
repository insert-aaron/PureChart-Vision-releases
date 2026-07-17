# PureChart-Vision-releases

**Distribution repo for PureChart Vision — installers live under
[Releases](https://github.com/insert-aaron/PureChart-Vision/releases), not in this
file tree.**

> Do **not** `git clone` this repo to install or update. It uses **Velopack**
> (a .NET auto-updater), so the app is distributed as GitHub **Release assets**,
> and the app updates itself. The old git-pull-on-launch model (PureXS/PureXR) is
> not used here.

## Install (once, per clinic PC)

1. Open the latest release:
   https://github.com/insert-aaron/PureChart-Vision-releases/releases/latest
2. Download **`PureChartVision-win-Setup.exe`** and run it.

That's it — no git, no admin, no .NET or Python install (all bundled).

## Updates (automatic)

On launch the app checks this repo's Releases feed, downloads any new version in
the background, and applies it silently **when you next close the app**. So each
close → reopen leaves you on the latest build. No action required.

## For maintainers

Every push to `main` on the source repo (`insert-aaron/PureChart-Vision`, private)
runs CI that builds the app and publishes a new GitHub Release here via
`vpk pack` + `vpk upload github`. The release assets are:

- `PureChartVision-win-Setup.exe` — the installer
- `PureChartVision-<ver>-full.nupkg` (+ delta packages) — update packages
- `RELEASES`, `releases.win.json` — the Velopack update feed
- `PureChartVision-win-Portable.zip` — portable build

This file tree intentionally holds only this README.
