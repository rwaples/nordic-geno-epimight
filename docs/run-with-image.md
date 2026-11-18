# Run the kit with the Apptainer image

For a Linux server without internet access, such as TSD. The image holds the kit, all its
software, the shared plan and these docs, so the server needs neither pixi nor this
repository. It needs Apptainer or Singularity (the commands are the same with
`singularity` in place of `apptainer`). A Windows remote desktop, such as MONA, can't run
it.

Each release puts `nordic-geno-epimight-<version>.sif` (about 1 GB) and its `.sha256`
file on the [releases page](https://github.com/rwaples/nordic-geno-epimight/releases).

Below, `IMAGE` stands for the path of the `.sif` file.

## 1. Import the image

Download the `.sif` and its `.sha256` on a computer with internet access, import both the
way your server imports any file, then check the file on the server:

```sh
sha256sum -c nordic-geno-epimight-<version>.sif.sha256
```

## 2. Learn `--bind`

Inside the image, the kit sees only your home folder, the folder you run from, and `/tmp`.
Name every other folder it must read or write with `--bind`, separated by commas:

```sh
apptainer run --bind /tsd/p00/data/durable/epimight,/tsd/p00/data/durable/out IMAGE ...
```

A folder you bind must already exist, so create the output folder's parent (`mkdir -p`)
before the first run and bind that, or bind an existing folder above it. Bind the folder
your files are really in. If a path is a link, or passes through one,
`realpath <path>` prints the folder to bind. If you forget one, the kit says a file or
folder is not found and reminds you of `--bind`.

`apptainer run IMAGE help` lists the commands: `study`, the six steps (`check`, `cohort`,
`epimight`, `tables`, `report`, `export`), `selftest`, `template` and `pedsum`.

## 3. Run the self-test

```sh
apptainer run --bind /path/to IMAGE selftest /path/to/selftest-out/
```

It runs the kit on a small simulated site and compares the results with values computed
independently. It takes about 2 minutes, prints one PASS, FAIL or SKIP line per check,
and exits 1 if any check fails. It needs a new or empty folder.

## 4. Prepare your data

Follow [step-0.md](step-0.md): it gives the formats of the pedigree and trait files and
the rules from the statistical analysis plan. With the initial plan you need one pedigree
file and the 19 trait files of window W1.

The files you need from the repository are in the image under `/opt/kit`. Copy them out:

```sh
apptainer exec IMAGE cat /opt/kit/Definitions/Phenotype_list.tsv > Phenotype_list.tsv
apptainer exec IMAGE cat /opt/kit/plan/traits.tsv > traits.tsv
apptainer exec IMAGE cat /opt/kit/docs/step-0.md > step-0.md
```

`apptainer exec IMAGE ls /opt/kit /opt/kit/docs` lists the rest.

Run pedsum from the image (step-0, section 1.4), with your folders bound:

```sh
apptainer run --bind /path/to/data IMAGE pedsum validate \
  --in /path/to/data/pedigree.tsv --out /path/to/data/pedsum/ \
  --birth-year-col birth_year --birth-date-col birth_date --twin-max-days 1 \
  --max-children-mother 20 --max-children-father 50
gunzip -c /path/to/data/pedsum/validate.tsv.gz > /path/to/data/pedigree_validated.tsv
```

## 5. Write your site file

```sh
apptainer run IMAGE template > denmark.yaml
```

prints a site file whose plan is the one in the image:

```yaml
# Site file for the nordic-geno-epimight image. The image must see every folder below:
# with Apptainer, --bind those outside your home folder, the current folder and /tmp;
# with Docker, mount each with -v at the same path.
site: Denmark                         # the name your results carry
plan: /opt/kit/plan/initial.yaml      # the shared plan: initial.yaml, later complete.yaml
data_folder: /path/to/trait/files     # one trait file per trait in the plan
...
```

Keep the `plan:` line and fill in the rest as [step-0.md, section 3](step-0.md#3-the-site-file)
says, with full paths.

## 6. Check your inputs

```sh
mkdir -p /path/to/out
apptainer run --bind /path/to/data,/path/to/out IMAGE check denmark.yaml /path/to/out/
```

Fix every `STOP` in `/path/to/out/1_check/findings.tsv` and run it again until it passes.
[outputs.md](outputs.md#when-a-run-stops) explains the findings. Then do the checks in
[step-0.md, section 4.2](step-0.md#42-what-you-check).

## 7. Run every step

```sh
apptainer run --bind /path/to/data,/path/to/out IMAGE study denmark.yaml /path/to/out/
```

`study` runs check, cohort, epimight, tables, report and export in order and stops at the
first that fails. One step at a time: `apptainer run ... IMAGE <step> denmark.yaml /path/to/out/`.
On a cluster, put the same command in your job script.

The kit has not been timed on a full register yet; the toy site (4,500 people, 38
EPIMIGHT calls) takes about 40 seconds and 0.5 GB. EPIMIGHT runs its calls one after
another: about 1,630 calls for the initial plan's 537 analyses. Run `check` and `cohort` on their own
first to see how long reading your data takes; `3_epimight/jobs.tsv` lists each call's
seconds. Each `run.yaml` records the image's version and commit under `kit`.

## 8. Review and send the export

Send only `/path/to/out/6_export/`, after the review in
[outputs.md](outputs.md#the-folder-to-share). Nothing else in the output folder may leave
your server.

## With the Docker image instead

The same kit is on Docker Hub as `biopsyk/nordic-geno-epimight` (amd64), for servers that
can reach it. Singularity or Apptainer can pull it as a `.sif`; the commands are then
`exec IMAGE nordicepimight <command>`, where this page has `run IMAGE <command>`:

```sh
singularity pull docker://biopsyk/nordic-geno-epimight:<version>
singularity exec --bind /path/to/data nordic-geno-epimight_<version>.sif \
  nordicepimight check denmark.yaml /path/to/out/
```

With Docker itself, mount each folder at its own path and run as yourself:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":"$PWD" -w "$PWD" \
  -v /path/to/data:/path/to/data biopsyk/nordic-geno-epimight:<version> \
  nordicepimight study denmark.yaml out/
```

[container/docker/README.md](../container/docker/README.md) has more examples.

## Later: the complete plan

Change `plan:` in your site file to `/opt/kit/plan/complete.yaml` and use a new output
folder. A change to the plan or the kit comes as a new image.
