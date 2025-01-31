# GameBuild

GameBuild is a PowerShell script for running, packaging, and publishing (packing into an executable) games made with [Love2D](https://love2d.org/).

Created by **Rafael Longhi**. Licensed under the **Zero-Clause BSD License**.

## Features

- **Package**: Compresses the `src/` folder into `build/game.love`.
- **Publish**: Builds a distributable version of the game:
  - Clears the `build/` folder.
  - Packages the game (creating `build/game.love`).
  - Copies the Love2D runtime (downloaded if needed) into `build/`.
  - Concatenates `love.exe` with `build/game.love` to create a standalone executable named after your game (e.g., `SuperGame.exe`).
  - Removes unwanted files, leaving only essential ones:
    - `SDL2.dll`, `OpenAL32.dll`, `<YourGame>.exe`, `license.txt`,
    - `love.dll`, `lua51.dll`, `mpg123.dll`, `msvcp120.dll`, `msvcr120.dll`.
- **Run**: Launches the game from source using the Love2D runtime (downloaded if needed).
- **Clean**: Removes all build artifacts.

## Installation

Ensure you have PowerShell installed (Windows only) and fork this repository **or** download the `gamebuild.ps1` file.

## Usage

Ensure your game's source code (`main.lua` file) is inside the `src/` folder.

Place a `game.ini` file beside the script with the following format:

```
name=My Awesome Game
loveVersion=11.5
```

If `game.ini` is missing, the script will generate a template file and exit.

Run the script with one of the following commands:

```
.\gamebuild.ps1 package   # Packages the game into a .love file
.\gamebuild.ps1 publish   # Builds a distributable executable
.\gamebuild.ps1 run       # Runs the game from source
.\gamebuild.ps1 clean     # Removes build artifacts
```

## License

This project is licensed under the **Zero-Clause BSD License** (0BSD) available in the LICENSE.txt file.

