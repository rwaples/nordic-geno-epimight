# nordic-geno-epimight

A kit for estimating heritability and genetic correlation from register data with
[EPIMIGHT](https://github.com/BioPsyk/epimight), with pedigree-pair sandwich standard
errors. The kit is under construction; this README grows with it.

## Install

Install [pixi](https://pixi.sh) (0.76), then from this folder:

```sh
pixi install --locked   # R, Rust, Python and their packages, from conda-forge
pixi run setup          # builds epimight and pedigreegraph from their pinned commits
```

`pixi run setup` needs internet access and compiles Rust, which takes a few minutes the
first time. The pinned commits are in `nordicepimight/inst/pins.yaml`.

## Also here

- `R/make_epimight_tte.R`, its guide in `docs/`, and `R/Summarise_incidence.R`: the
  collaborators' scripts.
- `Definitions/Phenotype_list.tsv`: the phenotype definitions.
- `GLOSSARY.md` and `docs/adr/`: the kit's terms and design decisions.
