# nordic-geno-epimight Docker Image

This Docker image provides [nordic-geno-epimight](https://github.com/rwaples/nordic-geno-epimight), the kit that runs [EPIMIGHT](https://github.com/BioPsyk/epimight) analyses in the same way across the registers of Denmark, Norway and Sweden.

## Description

The kit checks a site's pedigree and trait files, builds EPIMIGHT's input, runs EPIMIGHT for every heritability (h²) and genetic correlation (rg) in the shared plan, and writes result tables, a report and a folder to export with small counts suppressed. It works in birth-year strata and reports sandwich standard errors for related probands. The pedigree is checked with [pedsum](https://github.com/rwaples/pedsum).

The image holds the kit, all its software and the shared analysis plan, so it runs without internet access. The same kit also ships as an Apptainer `.sif` on the kit's [releases page](https://github.com/rwaples/nordic-geno-epimight/releases).

## Version Information

- Internal image version: 1.0.0
- Kit version: release tag `NGE_REF` (default `v0.1.0`). The tag and commit are in `/opt/kit/IMAGE_VERSION`, and every run records them in its `run.yaml`
- EPIMIGHT, pedigreegraph and pedsum: the versions the kit pins (`/opt/kit/kit/nordicepimight/inst/pins.yaml`, `/opt/kit/pixi.toml`)
- R 4.5 and Python, from the kit's `pixi.lock`
- Architecture: amd64 only (the lock file covers linux-64)

Installed versions are listed in `/etc/nordic-geno-epimight-version`.

## Included Tools

- **nordicepimight**: the kit's command (`study`, `check`, `cohort`, `epimight`, `tables`, `report`, `export`, `selftest`, `template`, `pedsum`, `help`)
- **pedsum**: through `nordicepimight pedsum`, to check or repair a pedigree before the run
- The shared plan: `/opt/kit/plan/initial.yaml` and `/opt/kit/plan/complete.yaml`
- The kit's README and docs: `/opt/kit/README.md`, `/opt/kit/docs/`

## Usage

The container sees only the folders you mount. Mount each folder the site file names at
the same path inside the container, so the paths in the site file work as written, and
run as yourself so the output belongs to you:

```bash
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD":"$PWD" -w "$PWD" \
  -v /path/to/registers:/path/to/registers \
  biopsyk/nordic-geno-epimight:1.0.0 nordicepimight study denmark.yaml out/
```

### Basic Usage

```bash
# Show the commands
docker run --rm biopsyk/nordic-geno-epimight nordicepimight help

# Run the self-test on the kit's toy study (about 2 minutes)
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/data \
  biopsyk/nordic-geno-epimight nordicepimight selftest selftest-out/

# Write a site file to fill in; it already names the plan in the image
docker run --rm biopsyk/nordic-geno-epimight nordicepimight template > denmark.yaml

# Check and repair the pedigree with pedsum (step 0)
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/data \
  biopsyk/nordic-geno-epimight nordicepimight pedsum validate \
  --in pedigree.tsv --out pedsum/ --birth-date-col birth_date --twin-max-days 1

# One step at a time: check, cohort, epimight, tables, report, export
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":"$PWD" -w "$PWD" \
  biopsyk/nordic-geno-epimight nordicepimight check denmark.yaml out/
```

Send `out/6_export/` only. Everything else in `out/` holds individual-level data.

### Using with Singularity

```bash
singularity pull docker://biopsyk/nordic-geno-epimight:1.0.0
singularity exec nordic-geno-epimight_1.0.0.sif nordicepimight help
singularity exec -B /path/to/registers nordic-geno-epimight_1.0.0.sif \
  nordicepimight study denmark.yaml out/
```

Singularity shows the container your home folder, the current folder and `/tmp`; bind
every other folder the site file names with `-B`.

## Notes

- The container runs as a non-root user; pass `--user "$(id -u):$(id -g)"` so it can write to your folders
- The working directory is `/data`
- A file or folder the container can't see stops the run with a `not found` message and a reminder to mount it
- The kit's full guide, including the input formats and step 0, is in `/opt/kit/README.md` and at https://github.com/rwaples/nordic-geno-epimight

## Building the Image

From this directory:

```bash
docker build -t biopsyk/nordic-geno-epimight:latest .
```

To build another kit release, tag or commit:

```bash
docker build --build-arg NGE_REF=v0.1.0 -t biopsyk/nordic-geno-epimight:latest .
```

The build needs internet access. It compiles EPIMIGHT and pedigreegraph and runs the kit's unit tests, taking about 5 minutes.

It downloads EPIMIGHT and pedigreegraph through the GitHub API, which allows 60 anonymous requests an hour per address. On a shared address, such as a CI runner, give the build a GitHub token as a secret; it is not stored in the image:

```bash
GITHUB_PAT=<token> docker build --secret id=github_pat,env=GITHUB_PAT -t biopsyk/nordic-geno-epimight:latest .
```

## References

- [nordic-geno-epimight GitHub repository](https://github.com/rwaples/nordic-geno-epimight)
- [EPIMIGHT](https://github.com/BioPsyk/epimight)
- [pedsum](https://github.com/rwaples/pedsum)
- [pedigree-graph](https://github.com/rwaples/pedigree-graph)

## License

License pending.
