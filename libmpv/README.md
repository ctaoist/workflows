# Custom libmpv builds

The `Build custom libmpv` workflow builds the audio-focused libmpv packages
used by desktop applications. It is started manually from GitHub Actions.

Outputs:

- Windows x64: `libmpv-2.dll`, the import library, and libmpv C headers in a
  `.7z` archive.
- Linux x86_64: the versioned `libmpv.so` shared library, C headers,
  `pkg-config` metadata, license, configure log, and runtime dependency list in
  a `.tar.gz` archive. The binary uses an Ubuntu 24.04 runtime baseline and
  enables ALSA, PulseAudio, and PipeWire output.
- macOS: arm64/x86_64 universal XCFrameworks in a `.tar.gz` bundle, plus the
  individual framework `.zip` archives.

All jobs pin their source or external build definitions to reviewed commits.
Windows uses the media-kit/shinchiro MinGW build with GPL and video output
disabled; Linux builds mpv 0.40.0 directly with GPL and player UI disabled;
macOS uses the `macos-universal-audio-default` Nix target. Change the pinned
commits in the workflow only as an explicit dependency upgrade.

`upload_artifacts` controls whether a run keeps GitHub Actions artifacts for 30
days. `publish_release` is independent: when artifacts are disabled, temporary
run-scoped caches transfer the platform outputs to the Release job. Enable
`replace_existing_assets` before overwriting an existing Release. Releases also
include `SHA256SUMS` and build metadata for all platforms.
