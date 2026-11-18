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

The machine needs internet access for the install and `setup`. An offline Windows remote
desktop, such as Statistics Sweden's MONA, can't run the kit (ADR 0006).

## 1. Install the tools

In PowerShell, as yourself (not as administrator):

```powershell
winget install --id Git.Git -e --source winget --scope user
$env:PIXI_VERSION = "v0.84.1"; irm -useb https://pixi.sh/install.ps1 | iex
Invoke-WebRequest https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe -OutFile $env:TEMP\rustup-init.exe
& $env:TEMP\rustup-init.exe -y --default-host x86_64-pc-windows-gnu --default-toolchain 1.99.1 --profile minimal
```

Without winget, install Git for Windows from <https://git-scm.com/download/win> and choose
"Only for me". Rust 1.99.1 is the version the Linux environment locks (`pixi.lock`), so
every site compiles pedigreegraph with the same Rust; CI checks that every Rust version on
this page is that one.

**Close PowerShell and open a new window**, so `PATH` has the three installers' folders.
Then check:

```powershell
git --version
pixi --version                            # pixi 0.84.1
cargo -vV | Select-String 'host|release'  # host: x86_64-pc-windows-gnu, release: 1.99.1
```

If you already had rustup with its default MSVC host and no Visual Studio Build Tools,
switch it instead of reinstalling:

```powershell
rustup toolchain install 1.99.1-x86_64-pc-windows-gnu --profile minimal
rustup default 1.99.1-x86_64-pc-windows-gnu
```

## 2. Get the kit and build it

```powershell
cd $HOME
git clone https://github.com/rwaples/nordic-geno-epimight.git
cd nordic-geno-epimight
pixi install --locked
pixi run --locked setup
```

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

## 4. Run your study

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
| `Matrix ... did not build from CRAN's source` | CRAN couldn't be reached | Check internet access, then rerun `setup` |

Anything else: send the end of the output, for example from
`pixi run --locked setup 2>&1 | Tee-Object setup.log`.
