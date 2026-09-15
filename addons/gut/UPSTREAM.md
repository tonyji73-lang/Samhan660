# Vendored GUT test dependency

- Upstream: https://github.com/bitwes/Gut
- Release: [v9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1), for Godot 4.7.x.
- Source archive: https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip
- Archive SHA-256: `14969aa46adc84aa08cdd21b9f6d1a64addd92ae60b36f02d0521ed305aa4086`
- Scope: the upstream `addons/gut` directory, with its MIT license in `LICENSE.md`.
- Local source modifications: none. This provenance file is added locally.

LowPolyTerrain's two test scripts extend `GutTest`. Vendoring the actual framework
provides the missing base class and command-line runner on fresh checkouts.
The editor plugin does not need to be enabled to run these tests from the CLI.

Run from the project with Godot 4.7.2:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_lowpoly_terrain.ps1 -Godot '<path-to-Godot.exe>'
```
