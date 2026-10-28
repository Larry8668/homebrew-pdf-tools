class PdfTools < Formula
  include Language::Python::Virtualenv

  desc "Offline CLI for PDFs, image background removal, and image and video compression"
  homepage "https://github.com/Larry8668/pdf-tools"
  url "https://github.com/Larry8668/pdf-tools/archive/6cdf6c5b859c405eb73455069066b50cb810ea0a.tar.gz"
  version "0.3.0"
  sha256 "5e0803af21bd474bcbd8b25330057eee06ff1e8efd52dfca0f1f9a717ae93d09"

  depends_on "ffmpeg"
  depends_on "python@3.13"

  def install
    python = formula_opt_bin("python@3.13")/"python3.13"
    venv = virtualenv_create(libexec, python)
    pip = [python, "-m", "pip", "--python=#{venv.root}/bin/python", "install", "--no-compile"]

    # PyMuPDF bundles MuPDF; building it from an sdist is slow and fragile, so dependencies
    # come from the upstream lock as prebuilt wheels, each checked against its hash.
    system(*pip, "--require-hashes", "--only-binary=:all:", "--no-deps", "-r", "requirements.lock.txt")
    system(*pip, "--no-deps", buildpath)

    bin.install_symlink libexec/"bin/pdf-tools"
  end

  def caveats
    <<~EOS
      Run `pdf-tools` to list every command, and `pdf-tools help <command>` for its options.

      Paths are relative to the folder you run a command from. Nothing is read from or
      written to a fixed folder: `-o out/merged.pdf` creates ./out/ if it is missing.

      `pdf-tools image-remove-bg` downloads its model (about 220 MB) on first use to
      ~/.cache/pdf-tools/models. Images are processed locally and never uploaded.
    EOS
  end

  test do
    assert_match "pdf-tools #{version}", shell_output("#{bin}/pdf-tools --version")
    assert_match "redact-area", shell_output(bin/"pdf-tools")
    assert_match "usage: pdf-tools merge", shell_output("#{bin}/pdf-tools help merge")
    assert_match "Did you mean 'merge'", shell_output("#{bin}/pdf-tools mrge 2>&1", 2)

    system libexec/"bin/python", "-c", <<~PY
      from PIL import Image
      Image.new("RGB", (400, 300), "red").save("a.png")
      Image.new("RGB", (300, 400), "blue").save("b.jpg")
    PY

    system bin/"pdf-tools", "merge", "a.png", "b.jpg", "-o", "out/merged.pdf"
    assert_path_exists testpath/"out/merged.pdf"

    system bin/"pdf-tools", "remove-pages", "out/merged.pdf", "--pages", "2", "-o", "one.pdf"
    system bin/"pdf-tools", "compress", "out/merged.pdf", "--image-quality", "30", "-o", "small.pdf"
    system bin/"pdf-tools", "redact-area", "out/merged.pdf", "--area", "1:0,0,100,100", "-o", "area.pdf"
    assert_match "Image size: 800 x 600 pixels",
                 shell_output("#{bin}/pdf-tools render-page out/merged.pdf --page 1 -o p.png")
    system bin/"pdf-tools", "image-pad-square", "a.png", "--size", "64", "-o", "sq.png"
    system bin/"pdf-tools", "image-compress", "a.png", "--quality", "50", "-o", "a.jpg"

    system formula_opt_bin("ffmpeg")/"ffmpeg", "-loglevel", "error", "-f", "lavfi",
           "-i", "testsrc=duration=1:size=320x240:rate=10", "in.mp4"
    system bin/"pdf-tools", "video-compress", "in.mp4", "--no-audio", "-o", "out.mp4"
    assert_path_exists testpath/"out.mp4"

    assert_match "usage: pdf-tools image-remove-bg", shell_output("#{bin}/pdf-tools help image-remove-bg")
    ENV["PDF_TOOLS_MODEL_DIR"] = testpath/"models"
    assert_match "not downloaded yet",
                 shell_output("#{bin}/pdf-tools image-remove-bg a.png --no-download -o nobg.png 2>&1", 1)

    # Run background removal end to end without the 220 MB model: a 158-byte stand-in
    # with the same input/output shape (mean of RGB, times 10) marks bright pixels as
    # foreground, which checks onnxruntime and the whole pipeline under this Python.
    (testpath/"models").mkpath
    (testpath/"models/birefnet-general-lite.onnx").binwrite <<~B64.unpack1("m")
      CAg6kwEKMAoBeBIBbSIKUmVkdWNlTWVhbioLCgRheGVzQAGgAQcqDwoIa2VlcGRpbXMYAaABAgoOCgFtCgFrEgF5IgNN
      dWwSBGZha2UqCxABIgQAACBBQgFrWh0KAXgSGAoWCAESEgoCCAEKAggDCgMIgAgKAwiACGIdCgF5EhgKFggBEhIKAggB
      CgIIAQoDCIAICgMIgAhCBAoAEBE=
    B64
    system libexec/"bin/python", "-c", <<~PY
      from PIL import Image
      im = Image.new("RGB", (300, 200), "black")
      im.paste((255, 255, 255), (100, 50, 200, 150))
      im.save("square.png")
    PY
    system bin/"pdf-tools", "image-remove-bg", "square.png", "--crop", "-o", "cut.png"
    system libexec/"bin/python", "-c", <<~PY
      from PIL import Image
      im = Image.open("cut.png")
      assert im.mode == "RGBA" and 100 <= im.width < 120, (im.mode, im.size)
      assert im.getchannel("A").getpixel((im.width // 2, im.height // 2)) > 240
    PY

    assert_match "No matching searchable text",
                 shell_output("#{bin}/pdf-tools redact out/merged.pdf --term nope -o r.pdf 2>&1", 1)
  end
end
