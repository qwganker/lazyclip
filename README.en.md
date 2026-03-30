# <img src="./icons/jiantie.png" alt="history" height="25" width="25"/>  LazyClip | [中文](./README.md)

LazyClip is a lightweight, native, local-only clipboard history app for the macOS menu bar.

## Screenshots

<img src="./docs/imgs/image.png" alt="history" height="400" width="600"/>
<img src="./docs/imgs/image2.png" alt="history" height="400" width="600" />

## Features

- Always available from the menu bar, so you can open the history panel at any time
- Automatically records plain-text/images clipboard history
- Persists data locally with SQLite
- Searches clipboard history
- Click an item to copy it back to the system clipboard
- Favorite / unfavorite frequently used content
- Delete individual history items
- Pause / resume clipboard recording
- Clear all saved history
- Configure the maximum history retention limit

## Packaging

```bash
./scripts/build-dmg.sh
```

This script builds the Release version of the app and generates:

- `build/DerivedData/Build/Products/Release/LazyClip.app`
- `build/LazyClip.dmg`

Install and run *LazyClip.dmg*.
