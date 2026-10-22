# homebrew-pdf-tools

Homebrew tap for [pdf-tools](https://github.com/Larry8668/pdf-tools): offline command-line tools to merge, compress, and redact PDFs, plus image and video compression.

```sh
brew tap Larry8668/pdf-tools
brew trust Larry8668/pdf-tools     # Homebrew 7+: third-party taps must be trusted
brew install pdf-tools
```

Installs one command, `pdf-tools`. Run it on its own to list everything it does, and `pdf-tools help <command>` for options:

```sh
pdf-tools merge a.pdf photo.png b.pdf -o merged.pdf
pdf-tools redact doc.pdf --terms "Jane Doe,12345" -o redacted.pdf
pdf-tools video-compress rec.mov --screenshare -o rec.mp4
```

`ffmpeg` and Python 3.13 come in as dependencies.

Paths are relative to the folder you run a command from. There's no fixed input or output folder, and `-o out/file.pdf` creates `out/` if needed.

The formula installs the release's `requirements.lock.txt` as prebuilt wheels, each checked against its hash, so you get the same Pillow, PyMuPDF and pypdf versions as the repo's `uv.lock`.
