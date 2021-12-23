# DevKit

This repo contains tools that I use to generate DevKits, ignore them.

If you're looking for DevKits, check the releases tab or [click here for the latest.](https://github.com/BigscreenModded/DevKit/releases/latest)

### If you're really that interested...

`genDevKit.ps1` generates a devkit from the steam version of the game. It copies the DLLs from the MelonLoader/Managed folder and then removes useless DLLs such as `mscorlib.dll` ect. It then zips them up into <game-version>.zip with the format you see DevKits in currently. Finally, it uploads it to GitHub as a release.