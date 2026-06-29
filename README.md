# PureChart-Vision-releases

Deployed binaries for **PureChart Vision** (built artifacts only — not source).

Populated by `scripts/build-and-deploy.sh` / CI from the source repo. Contains:

- `PureChartVision.exe` + self-contained .NET 8 runtime (x64)
- `PluginHost.exe` — x86 net48 TWAIN host (intraoral capture)
- `python/` — embedded Python interpreter
- `decoder/` — Python reconstruction pipeline (panoramic)
- `SetupAndRun.bat` — clinic installer/updater/launcher

Clinic PCs run `SetupAndRun.bat`, which `git reset --hard` to the latest
commit here and launches the app. **Do not commit source or PHI to this repo.**
