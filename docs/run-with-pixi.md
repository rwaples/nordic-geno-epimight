# Run the kit with pixi

For a Linux server with internet access. On 64-bit Windows, install with
[windows.md](windows.md) and then follow this page from step 4. On a server without
internet, use the [Apptainer image](run-with-image.md) instead.

Run every `pixi run` command from the kit's folder (`nordic-geno-epimight/`): pixi finds
the kit there. Keep your data and anything made from it (pedsum's output, `out/`)
outside that folder, and give their paths in full.

## 1. Install pixi

The kit needs [pixi](https://pixi.sh) 0.84. pixi installs one program under
`~/.pixi/bin` and doesn't need root. Its installer fetches the latest version unless told
otherwise, and the kit refuses any other series, so name the version:

```sh
curl -fsSL https://pixi.sh/install.sh | PIXI_VERSION=v0.84.1 bash
export PATH="$HOME/.pixi/bin:$PATH"
pixi --version
```

The installer also adds `~/.pixi/bin` to `PATH` in your shell's startup file. If
`pixi --version` fails in a new terminal, add the `export` line there yourself. If you
already have pixi at another version, switch with `pixi self-update --version 0.84.1`.

## 2. Install the kit

```sh
git clone https://github.com/rwaples/nordic-geno-epimight.git
cd nordic-geno-epimight
pixi install --locked
pixi run setup
```

`pixi install` installs R, Python and pedsum, the pedigree checker. `pixi run setup`
downloads and compiles EPIMIGHT and pedigreegraph at the versions the kit is tested with
(its "pins"). It needs internet access and takes about 3 minutes the first time.

## 3. Run the self-test

```sh
pixi run selftest selftest-out/
```

It runs the kit on a small simulated site and compares the results with values computed
independently. It takes about 2 minutes, prints one PASS, FAIL or SKIP line per check,
and exits 1 if any check fails. It needs a new or empty folder: delete `selftest-out/`
before running it again.

To see a full run and its outputs, run the toy site yourself:

```sh
pixi run study kit/selftest/toy/site.yaml /path/to/toy-out/
```

## 4. Prepare your data

Follow [step-0.md](step-0.md): it gives the formats of the pedigree and trait files,
how to run pedsum, and the rules from the statistical analysis plan. With the initial
plan you need one pedigree file and the 19 trait files of window W1.

## 5. Write your site file

```sh
cp local/example.yaml local/denmark.yaml
```

Fill it in as [step-0.md, section 3](step-0.md#3-the-site-file) says. Files in `local/`
other than the example are never committed, since they describe your data.

## 6. Check your inputs

```sh
pixi run check local/denmark.yaml /path/to/out/
```

Fix every `STOP` in `/path/to/out/1_check/findings.tsv` and run it again until it passes.
[outputs.md](outputs.md#when-a-run-stops) explains the findings. Then do the checks in
[step-0.md, section 4.2](step-0.md#42-what-you-check), which use
`1_check/pedigree_coverage.tsv`.

## 7. Run every step

```sh
pixi run study local/denmark.yaml /path/to/out/
```

`study` runs check, cohort, epimight, tables, report and export in order and stops at the
first that fails. You can also run one step at a time:
`pixi run <step> local/denmark.yaml /path/to/out/`.

**Time and memory.** The kit has not been timed on a full register yet. The toy site
(4,500 people, 2 traits, 12 analyses, 38 EPIMIGHT calls) takes about 40 seconds and 0.5 GB
with `threads: 2`. EPIMIGHT runs its calls one after another, about three per analysis plus
one per trait: about 1,630 for the initial plan's 537 analyses and 3,270 for the complete one's
1,083. To measure your site:

- Run `check` and `cohort` on their own first. They read every input and build the
  largest table, `cohort.tsv`.
- The `epimight` step prints each call's seconds, and `3_epimight/jobs.tsv` lists them.
- `threads` in the site file speeds up pedsum, the relative counts and the sandwich SEs.
  Don't set it above the cores you were given.
- Put `/usr/bin/time -v` in front of a command to see its peak memory ("Maximum resident
  set size").

## 8. Review and send the export

Send only `/path/to/out/6_export/`, after the review in
[outputs.md](outputs.md#the-folder-to-share). Nothing else in the output folder may leave
your server.

## Later: the complete plan

Change `plan:` in your site file to `../plan/complete.yaml` and use a new output folder.

## Updating the kit

```sh
git pull
pixi install --locked
pixi run setup
```

Then rerun from `check`: every step after it stops if the kit changed since `check` ran.
