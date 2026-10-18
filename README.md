# Vorssaint Intel Builder

Build [Vorssaint](https://github.com/vorssaint/vorssaint-utils) from its official source for **Intel (x86_64) Macs**.

Vorssaint only ships Apple Silicon builds, so on an Intel Mac the official app fails to open with *"this application is not supported on this Mac"*. The source itself compiles fine for x86_64: only the target triple in upstream's `build.sh` is pinned to `arm64`. This script fetches an official release, changes that one line, and builds it on your own machine.

> [!NOTE]
> This is an unofficial helper. It is not affiliated with or endorsed by the Vorssaint project, and the maintainers [do not support Intel Macs](https://github.com/vorssaint/vorssaint-utils/issues/523). Please don't report Intel-specific problems upstream.

## Requirements

- An Intel Mac on macOS 14 (Sonoma) or later
- Apple Command Line Tools with Swift 6: `xcode-select --install`

## Usage

```bash
git clone https://github.com/kitsuneislife/vorssaint-intel-builder.git
cd vorssaint-intel-builder
./build.sh --install
```

| Option | What it does |
|---|---|
| `--install` | Moves any existing `/Applications/Vorssaint.app` to the Trash and installs the new build there |
| `--version <tag>` | Builds a specific release (for example `v3.4.1`) instead of the latest one |
| *(no options)* | Builds the latest release into `./dist/Vorssaint.app` without installing |

To update, run `./build.sh --install` again whenever a new Vorssaint release comes out.

## How it works

1. Looks up the latest release tag of `vorssaint/vorssaint-utils` (or uses `--version`).
2. Shallow-clones that tag into a temporary folder.
3. Changes `TARGET="arm64-apple-macosx14.0"` to `x86_64` in upstream's `build.sh`.
4. Runs upstream's own build, which signs the app ad-hoc on your Mac.
5. Checks that the binary is `x86_64` and the signature is valid, then installs or copies it.

No binaries or upstream code are stored in this repository. Everything you run comes straight from the official source.

## Known limitations

- **Temperature sensors** (CPU, GPU, battery) may show nothing, because sensor discovery skips the SMC keys Intel Macs use ([details](https://github.com/vorssaint/vorssaint-utils/issues/1130)).
- **Privacy permissions** (Accessibility, Screen Recording) are tied to the exact binary. After a rebuild, macOS may show them as granted while the app is no longer trusted. If a feature stops working, remove Vorssaint from the list in System Settings → Privacy & Security and add it again.
- **Updates**: don't use the in-app updater, which would install the Apple Silicon build. Re-run the script instead.
- Features that depend on Apple Silicon-only hardware will not work.

## Tested on

| Mac | macOS | Vorssaint |
|---|---|---|
| Intel Core i5-13420H | 15.8.1 | v3.4.1 |

## License

The script in this repository is released under the [MIT License](LICENSE). Vorssaint is licensed under GPL-3.0-or-later, and its name and branding belong to its maintainers (see their [TRADEMARKS.md](https://github.com/vorssaint/vorssaint-utils/blob/main/TRADEMARKS.md)).
