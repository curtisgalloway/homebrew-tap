<!--
Copyright 2026 Curtis Galloway

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# curtisgalloway/homebrew-tap

Homebrew formulae for [Curtis Galloway](https://github.com/curtisgalloway)'s
projects.

## Usage

```bash
brew tap curtisgalloway/tap
brew install paniolo
```

Or in one step: `brew install curtisgalloway/tap/paniolo`.

## Formulae

| Formula | Description |
|---|---|
| [`paniolo`](Formula/paniolo.rb) | Agent-controlled target machine wrangler — distributed bring-up control over SSH ([repo](https://github.com/curtisgalloway/paniolo)) |

`paniolo` installs the CLI on PATH with its helper daemons in the formula's
private libexec. On macOS it pours a **precompiled bottle** — no Rust toolchain
required (bottles are built for Intel and Apple Silicon and published with each
release). If you're on a macOS version newer than the build hosts, Homebrew
uses the newest compatible bottle; if none matches it falls back to building
from source (Rust is pulled in automatically as a build-only dep).

On Linux there are no bottles — `brew install` would build from source, but the
prebuilt `.deb`s on
[GitHub Releases](https://github.com/curtisgalloway/paniolo/releases) are the
better-tested path.

## License

[Apache 2.0](LICENSE)
