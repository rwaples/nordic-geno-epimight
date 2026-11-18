# Running the kit on Windows

The kit's pixi route runs on 64-bit Windows (x86-64) without WSL, administrator rights,
Rtools or Visual Studio. This page is the whole install and a first run; from there
[run-with-pixi.md](run-with-pixi.md), step 4 on, applies unchanged.

What Windows needs that Linux gets from pixi alone:

- **Git for Windows**, to clone the kit.
- **Rust from rustup with its MinGW host** (`x86_64-pc-windows-gnu`). `setup` compiles
  pedigreegraph, whose build scripts the MSVC-hosted Rust (rustup's default, and
  conda-forge's) can only link with Visual Studio's `link.exe`. The MinGW host links with
  the same MinGW gcc that the pixi environment gives R.

The machine needs internet access for the install and `setup`: github.com and its
downloads (the kit, pedsum, pedigreegraph, EPIMIGHT, pixi), pixi.sh, conda.anaconda.org
and pypi.org (the pixi environment), static.rust-lang.org (Rust), crates.io and
static.crates.io (pedigreegraph's Rust crates) and cloud.r-project.org (Matrix's source).
Behind a proxy that blocks any of these, the step that needs it stops with a download or
timeout error. An offline Windows remote
desktop, such as Statistics Sweden's MONA, can't run the kit (ADR 0006).

## 1. Install or update the tools

In PowerShell, as yourself (not as administrator), paste this block. Each block on this
page ends with an empty line, so it runs as soon as it is pasted. It works on a new
machine and on one that already has some of the tools: it installs what is missing and
switches pixi and Rust to the versions the kit needs.

```powershell
# Git, if it isn't installed yet
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id Git.Git -e --source winget --scope user
  } else {
    Write-Host "No winget: install Git for Windows from https://git-scm.com/download/win ('Only for me')"
  }
}
# pixi 0.84.1: switch an installed pixi to it, else install it
$env:PIXI_VERSION = "v0.84.1"
if (Get-Command pixi -ErrorAction SilentlyContinue) { pixi self-update --version 0.84.1 }
if (-not (Get-Command pixi -ErrorAction SilentlyContinue) -or $LASTEXITCODE -ne 0) {
  irm -useb https://pixi.sh/install.ps1 | iex
}
# Rust 1.99.1 with the MinGW host: switch an installed rustup to it, else install it
if (Get-Command rustup -ErrorAction SilentlyContinue) {
  rustup toolchain install 1.99.1-x86_64-pc-windows-gnu --profile minimal
  rustup default 1.99.1-x86_64-pc-windows-gnu
} else {
  Invoke-WebRequest https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe -OutFile $env:TEMP\rustup-init.exe
  & $env:TEMP\rustup-init.exe -y --default-host x86_64-pc-windows-gnu --default-toolchain 1.99.1 --profile minimal
}

```

pixi 0.84 is the only series the kit accepts (`requires-pixi` in
`pixi.toml`): any other pixi stops every command with "This project requires pixi ...".
Rust 1.99.1 is the version the Linux environment locks (`pixi.lock`), so every site
compiles pedigreegraph with the same Rust; CI checks that every Rust version on this page
is that one.

**Close PowerShell and open a new window**, so `PATH` has the installers' folders, and
check all three:

```powershell
git --version
pixi --version                            # pixi 0.84.1
cargo -vV | Select-String 'host|release'  # host: x86_64-pc-windows-gnu, release: 1.99.1

```

If `pixi --version` still shows another version, an older pixi comes first on `PATH`:
`Get-Command pixi -All` lists every one. Remove the others, or put the right one first for
this window with `$env:Path = "$HOME\.pixi\bin;$env:Path"`.

## 2. Get or update the kit, and build it

The same block makes a first copy of the kit or brings an existing one up to date:

```powershell
cd $HOME
if (Test-Path nordic-geno-epimight\.git) {
  git -C nordic-geno-epimight pull --ff-only
} else {
  git clone https://github.com/rwaples/nordic-geno-epimight.git
}
cd nordic-geno-epimight
pixi install --locked
pixi run --locked setup

```

`git pull --ff-only` stops if you have changed a file of the kit's own: `git status` names
it, and `git restore <file>` puts it back. Your site file in `local/` is not the kit's and
stays as it is. After an update, run step 1's block again first if the kit's pixi or Rust
version has changed (this page names them), then this block.

`setup` takes several minutes the first time. Besides EPIMIGHT and pedigreegraph it
rebuilds the Matrix package from CRAN's source: conda-forge's Windows build of Matrix
can crash R on start with `Mingw-w64 runtime failure: 32 bit pseudo relocation ... out of
range`. It ends with `setup done: epimight ..., pedigreegraph ...`. A rerun skips what is
already built.

## 3. Check the install

```powershell
pixi run --locked test                    # [ FAIL 0 | WARN 0 | SKIP 0 | PASS ... ]
pixi run --locked selftest selftest-out   # one PASS, FAIL or SKIP line per check

```

The self-test must end with no FAIL. A SKIP line says why that check can't run, for
example a value with no independent reference, and is not a failure;
`kit/selftest/README.md` describes the toy site and the checks.
Give it a folder that doesn't exist yet: it refuses one that isn't empty.

## 4. Step 0 in PowerShell

[step-0.md](step-0.md) writes its pedsum commands for a Unix shell. In PowerShell a line
continues with a backtick, not `\`, and Windows has no `gunzip`; PowerShell 5.1's `>` would
also write UTF-16. The same two commands, from the kit's folder:

```powershell
pixi run --locked pedsum validate --in D:/data/pedigree.tsv --out D:/data/pedsum/ `
  --birth-year-col birth_year --birth-date-col birth_date --twin-max-days 1 `
  --max-children-mother 20 --max-children-father 50
pixi run --locked python -I -c "import gzip, shutil, sys; shutil.copyfileobj(gzip.open(sys.argv[1]), open(sys.argv[2], 'wb'))" D:/data/pedsum/validate.tsv.gz D:/data/pedigree_validated.tsv

```

Put your own paths in place of `D:/data/...`; step-0.md's other options (such as
`--multiple-birth-col` or `--missing-parent-token`) go in the same way.

## 5. Run your study

As in [run-with-pixi.md](run-with-pixi.md), from the kit's folder:

```powershell
Copy-Item local\example.yaml local\mysite.yaml   # then fill it in
pixi run --locked study local/mysite.yaml out/

```

In the site file, write paths with forward slashes (`D:/register/pedigree.tsv`); R and
pedsum read them on Windows, and YAML can't misread them as escapes.

A long call can be stopped with Ctrl-C (Esc in RStudio or Rgui); R returns to the prompt
and the next call works.

## What you may see that is harmless

- **Garbled symbols** such as `Ô£¿` or `Ôáÿ`. Windows PowerShell 5.1 shows pixi's and
  testthat's UTF-8 symbols in the old DOS code page. To see them properly, run
  `[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()` first, or use
  PowerShell 7 in Windows Terminal.
- **Red `NativeCommandError` blocks** around pixi's first line. PowerShell 5.1 wraps
  anything a program writes to stderr when you redirect it with `2>&1`.
- **`tar.exe: ... CLAUDE.md: Can't create ...`** during `setup`. The file is a link in
  pedigreegraph's repository, which Windows can't create without Developer Mode; the
  build doesn't use it.
- **`replacing previous import 'data.table::first' by 'dplyr::first'`** warnings, from
  EPIMIGHT's own imports.

## When the install fails

| What you see | Cause | Fix |
|---|---|---|
| `linking with link.exe failed` or `link: extra operand` while compiling `proc-macro2` | Rust has the MSVC host | Switch to the MinGW host (step 1) |
| `cargo not found` | rustup's folder isn't on `PATH` | Open a new PowerShell window; or add `$HOME\.cargo\bin` to `PATH` |
| `Rtools is required to build R packages` and `'{' is not recognized` | The environment's shell tools are missing | `pixi install --locked` again in the kit's folder |
| `could not find pixi.toml` | PowerShell is not in the kit's folder | `cd $HOME\nordic-geno-epimight` |
| `Mingw-w64 runtime failure: 32 bit pseudo relocation ... out of range` | A DLL with 32-bit pseudo-relocations | Rerun `setup`, then run `pixi run --locked python -I ci/find_pseudo_relocs.py .pixi/envs/default` and report what it lists |
| `Matrix is missing or broken in the pixi environment`, or `$ operator is invalid for atomic vectors` | A Matrix rebuild was stopped partway | Delete `.pixi\envs\default\lib\R\library\Matrix`, run `pixi reinstall --locked r-matrix`, then `pixi run --locked setup` |
| `R would install into ...` | Something put another library ahead of the environment's | Run setup with `pixi run --locked setup`, not R by hand; check that no `R_LIBS` variable is set in Windows' environment variables |
| `Matrix ... did not build from CRAN's source` | CRAN couldn't be reached | Check internet access, then rerun `setup` |
| `This project requires pixi ...` | Another pixi version is running | Step 1's block again; then the `Get-Command pixi -All` check |
| `Filename too long` or a build error naming a path over 260 characters | Windows' path limit | Clone the kit nearer the drive's root, for example `C:\nge` |
| A download that times out or is refused | A proxy or firewall | Ask for access to the sites listed at the top of this page |

Anything else: send the end of the output, for example from
`pixi run --locked setup 2>&1 | Tee-Object setup.log`.
