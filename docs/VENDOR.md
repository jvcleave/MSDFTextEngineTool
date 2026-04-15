# Vendored Dependencies

This project vendors a pinned snapshot of upstream `msdf-atlas-gen` so atlas generation stays stable and does not drift with upstream updates unless we explicitly choose to refresh it.

## Snapshot

- `msdf-atlas-gen`
  Upstream: `https://github.com/Chlumsky/msdf-atlas-gen`
  Commit: `2ede254314a2512252a225fa6c975948d6af559a`
  License: MIT
- `msdfgen`
  Upstream: `https://github.com/Chlumsky/msdfgen`
  Commit: `1874bcf7d9624ccc85b4bc9a85d78116f690f35b`
  License: MIT
- `artery-font-format`
  Upstream: `https://github.com/Chlumsky/artery-font-format`
  Commit: `af79386abe0857fe1c30be97eec760dbd84022c5`
  License: included in vendored snapshot

## Notes

- Nested git metadata has been removed so `Vendor/msdf-atlas-gen` is a true vendored snapshot, not a submodule.
- The `TextEngineTool` CLI builds the vendored generator into `.vendor-build/msdf-atlas-gen`.
- Upstream license files are preserved inside the vendored source tree.
- The vendored standalone source has one local compatibility patch in `msdf-atlas-gen/main.cpp` so it builds with the current Apple toolchain.
