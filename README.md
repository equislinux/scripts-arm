# scripts-arm — aarch64 delta for the x generations engine

ARM-only companion of [`equislinux/scripts`](https://github.com/equislinux/scripts)
(the x provisioning payload and CLI). `scripts` is consumed **read-only** at a
pinned commit; this repo owns the aarch64 delta and builds the package that
replaces `x-scripts` on ARM systems.

## Why a separate repo

The generations engine is x86_64-shaped: it globs `/boot/vmlinuz-*`, pairs
`initramfs-<pkgbase>.img` and reads `/usr/lib/modules/<rel>/pkgbase`. Arch
Linux ARM's `linux-aarch64` installs `/boot/Image(.gz)`, `initramfs-linux.img`
and no `pkgbase` file. Keeping the delta here means `equislinux/scripts`
(and therefore x86_64, WSL and everything else) is never modified; every ARM
change is a patch over a pinned upstream, reviewed in isolation.

## Layout

```
vendor/scripts.sha                    pinned commit of equislinux/scripts
patch/generations-aarch64.patch       the ARM delta (Image, pkgbase fallback)
build.sh                              pin -> patch -> x-scripts-arm package
out/                                  built packages (gitignored)
```

## Build

```bash
./build.sh                      # needs aarch64 + makepkg (or the x-arm Docker builder)
```

Produces `out/x-scripts-arm-<ver>-any.pkg.tar.zst` (identity derived from the
upstream `packaging/PKGBUILD`: `provides`/`conflicts`/`replaces` `x-scripts`).

Install on an aarch64 X system:

```bash
sudo pacman -U out/x-scripts-arm-*-any.pkg.tar.zst
x gen new --reason test
```

## Contents of the delta

- `xkernel.sh`: `linux-aarch64` in the known-kernel list; a single
  `xkernel_pkgbase_of()` fallback (ALARM ships no `pkgbase` file), restoring
  `x kernel` listing/removal safety on ARM.
- `xgen.sh`: archives `/boot/Image(.gz)`; synthesizes
  `pkgbase=linux-aarch64` for `kernels.tsv`; legacy pairing accepts `Image*`;
  the dedupe check compares `Image*` too.

Every fallback is conditional on `uname -m == aarch64` or on files that Arch
x86_64 does not install, so the delta is inert off-ARM by construction.

## Sync policy

- Bump `vendor/scripts.sha` deliberately when pulling upstream changes;
  re-apply the patch and re-run the upstream test suite on the patched tree
  (`bash test/validate.sh`, headless sections) before publishing.
- Publication: the package belongs in `[x]/aarch64` (published from
  `equislinux/x-arm-repo`); the installer integration lives in
  `equislinux/x-arm` (overlay).
