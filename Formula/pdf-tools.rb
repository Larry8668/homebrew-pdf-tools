class PdfTools < Formula
  include Language::Python::Virtualenv

  desc "Offline CLI to merge, compress and redact PDFs, plus image and video compression"
  homepage "https://github.com/Larry8668/pdf-tools"
  url "https://github.com/Larry8668/pdf-tools/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "6c185be5e5352f8d5031259bb7119777dcf58e23f9cf5fe57fb2e944497f8ee0"

  depends_on "ffmpeg"
  depends_on "python@3.13"

  COMMANDS = %w[
    pdf-merge pdf-compress pdf-remove-pages pdf-redact pdf-redact-area pdf-render-page
    image-compress image-pad-square video-compress
  ].freeze

  def install
    python = formula_opt_bin("python@3.13")/"python3.13"
    venv = virtualenv_create(libexec, python)
    pip = [python, "-m", "pip", "--python=#{venv.root}/bin/python", "install", "--no-compile"]

    # PyMuPDF bundles MuPDF; building it from an sdist is slow and fragile, so dependencies
    # come from the upstream lock as prebuilt wheels, each checked against its hash.
    system(*pip, "--require-hashes", "--only-binary=:all:", "--no-deps", "-r", "requirements.lock.txt")
    system(*pip, "--no-deps", buildpath)

    COMMANDS.each { |cmd| bin.install_symlink libexec/"bin"/cmd }
  end

  def caveats
    <<~EOS
      Paths are relative to the folder you run a command from. Nothing is read from or
      written to a fixed folder: `-o out/merged.pdf` creates ./out/ if it is missing.
    EOS
  end

  test do
    system libexec/"bin/python", "-c", <<~PY
      from PIL import Image
      Image.new("RGB", (400, 300), "red").save("a.png")
      Image.new("RGB", (300, 400), "blue").save("b.jpg")
    PY

    system bin/"pdf-merge", "a.png", "b.jpg", "-o", "out/merged.pdf"
    assert_path_exists testpath/"out/merged.pdf"

    system bin/"pdf-remove-pages", "out/merged.pdf", "--pages", "2", "-o", "one.pdf"
    system bin/"pdf-compress", "out/merged.pdf", "--image-quality", "30", "-o", "small.pdf"
    system bin/"pdf-redact-area", "out/merged.pdf", "--area", "1:0,0,100,100", "-o", "area.pdf"
    assert_match "Image size: 800 x 600 pixels",
                 shell_output("#{bin}/pdf-render-page out/merged.pdf --page 1 -o p.png")
    system bin/"image-pad-square", "a.png", "--size", "64", "-o", "sq.png"
    system bin/"image-compress", "a.png", "--quality", "50", "-o", "a.jpg"

    system formula_opt_bin("ffmpeg")/"ffmpeg", "-loglevel", "error", "-f", "lavfi",
           "-i", "testsrc=duration=1:size=320x240:rate=10", "in.mp4"
    system bin/"video-compress", "in.mp4", "--no-audio", "-o", "out.mp4"
    assert_path_exists testpath/"out.mp4"

    assert_match "No matching searchable text",
                 shell_output("#{bin}/pdf-redact out/merged.pdf --term nope -o r.pdf 2>&1", 1)
  end
end
