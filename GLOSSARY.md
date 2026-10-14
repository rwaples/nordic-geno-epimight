# nordic-geno-epimight

A kit that collaborators run on their own register data to estimate heritability and
genetic correlation with EPIMIGHT, with pedigree-pair sandwich standard errors.

## Language

**Kit**:
This repository as a collaborator runs it: install, checks, building the cohort table, EPIMIGHT, output and plots.
_Avoid_: runner, pipeline (EPIMIGHT's `Pipeline` is a different thing)

**Pedigree file**:
One row per person with their mother, father, sex and birth date.
_Avoid_: genealogy, parent table

**Trait**:
A named definition in the trait list: one trait file plus the follow-up and second-trait rules applied to it.
_Avoid_: phenotype, variant

**Trait file**:
One file per trait, one row per person, with that person's status, age and date for the trait.
_Avoid_: TTE table, phenotype file

**Study population**:
The people followed for every trait; each has exactly one row in every trait file.
_Avoid_: sample

**Status**:
A person's outcome for one trait: 1 the trait, 2 a competing event, 0 censored.
_Avoid_: failure status, affection

**Age**:
A person's age in years at their status: onset for 1, the competing event for 2, end of follow-up for 0.
_Avoid_: failure time, trait time

**Relationship**:
One of eight fixed kinds of relative (PO, FS, HS, mHS, pHS, Av, 1G, 1C), each with a fixed relatedness.
_Avoid_: relatives_kind, relationship kind

**Analysis**:
One EPIMIGHT estimate requested in the analysis list: h² for a trait, or rg for one direction between two traits, for one relationship.
_Avoid_: job, call

**Cohort table**:
EPIMIGHT's input table, one row per proband, trait and relationship, built by the kit.
_Avoid_: pool (EPIMIGHT's argument name), TTE, long table

**Population cohort**, **family-history cohort**, **cross cohort**:
The subsets of the cohort table EPIMIGHT draws for one analysis: everyone with the trait's rows; those with an affected relative of one relationship; the same for another trait's relatives.
_Avoid_: bare "cohort" for any of these

## Relationships

- A **Trait file** gives each person one **Status** and one **Age**
- Every **Trait file** covers the same **Study population**
- A **Trait** uses exactly one **Trait file**; a **Trait file** may serve several **Traits**
- An **Analysis** names one or two **Traits** and one **Relationship**
- The kit builds one **Cohort table** from the **Pedigree file** and every **Trait**
- Each **Analysis** draws a **Population cohort** and a **family-history** or **cross cohort** from the **Cohort table**

## Flagged ambiguities

- "pool" (EPIMIGHT's word) and "cohort" both named the kit's built table: resolved as **Cohort table**; a bare "cohort" is avoided, since EPIMIGHT's subsets are also cohorts.
