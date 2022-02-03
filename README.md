# Numbat

<!-- badges: start -->

[![<kharchenkolab>](https://circleci.com/gh/kharchenkolab/Numbat.svg?style=svg)](https://app.circleci.com/pipelines/github/kharchenkolab/Numbat)
  
<!-- badges: end -->

<img src="logo.png" align="right" width="200">

Numbat is a haplotype-enhanced CNV caller from single-cell transcriptomics data. It integrates signals from gene expression, allelic ratio, and population haplotype structures to accurately infer allele-specific CNVs in single cells and reconstruct their lineage relationship. 

Numbat can be used to 1. detect allele-specific copy number variations from single-cells 2. differentiate tumor versus normal cells in the tumor microenvironment 3. infer the clonal architecture and evolutionary history of profiled tumors. 

Numbat does not require paired DNA or genotype data and operates solely on the donor scRNA-data data (for example, 10x Cell Ranger output).

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Output descriptions](#output-descriptions)

A more detailed vignette for interpreting Numbat results is available:
- [Walkthrough](https://kharchenkolab.github.io/Numbat)

# Prerequisites
Numbat uses cellsnp-lite for generating SNP pileup data and eagle2 for phasing. Please follow their installation instructions and make sure their binary executables can be found in your $PATH.

1. [cellsnp-lite](https://github.com/single-cell-genetics/cellsnp-lite)
2. [eagle2](https://alkesgroup.broadinstitute.org/Eagle/)

Additionally, Numbat needs a common SNP VCF and phasing reference panel. You can use the 1000 Genome reference below:

3. 1000G SNP reference file 
```
# hg38
wget https://sourceforge.net/projects/cellsnp/files/SNPlist/genome1K.phase3.SNP_AF5e2.chr1toX.hg38.vcf.gz
# hg19
wget https://sourceforge.net/projects/cellsnp/files/SNPlist/genome1K.phase3.SNP_AF5e2.chr1toX.hg19.vcf.gz
```
4. 1000G Reference Panel
```
# hg38
wget http://pklab.med.harvard.edu/teng/data/1000G_hg38.zip
# hg19
wget http://pklab.med.harvard.edu/teng/data/1000G_hg19.zip
```

# Installation
Note that the dependencies `GenomicRanges` and `ggtree` can be installed via `BiocManager`:
```
BiocManager::install("GenomicRanges")
BiocManager::install("ggtree")
```
Install the Numbat R package via:
```
devtools::install_github("https://github.com/kharchenkolab/Numbat")
```

# Usage
1. Run the preprocessing script (`pileup_and_phase.R`): collect allele data and phase SNPs
```
usage: pileup_and_phase.R [-h] --label LABEL --samples SAMPLES --bams BAMS
                          --barcodes BARCODES --gmap GMAP --snpvcf SNPVCF
                          --paneldir PANELDIR --outdir OUTDIR --ncores NCORES
                          [--UMItag UMITAG] [--cellTAG CELLTAG]

Run SNP pileup and phasing with 1000G

optional arguments:
  -h, --help           show this help message and exit
  --label LABEL        Individual label
  --samples SAMPLES    Sample names, comma delimited
  --bams BAMS          BAM files, one per sample, comma delimited
  --barcodes BARCODES  Cell barcodes, one per sample, comma delimited
  --gmap GMAP          Path to genetic map provided by Eagle2
  --snpvcf SNPVCF      SNP VCF for pileup
  --paneldir PANELDIR  Directory to phasing reference panel (BCF files)
  --outdir OUTDIR      Output directory
  --ncores NCORES      Number of cores
  --UMItag UMITAG      UMI tag in bam. Should be Auto for 10x and XM for
                       Slide-seq
  --cellTAG CELLTAG    Cell tag in bam. Should be CB for 10x and XC for Slide-
                       seq
```

2. Run Numbat

In this example (ATC2 from [Gao et al](https://www.nature.com/articles/s41587-020-00795-2)), the gene expression count matrix and allele dataframe are already prepared for you.
```
library(Numbat)

# run
out = run_numbat(
    count_mat_ATC2, # gene x cell raw UMI count matrix 
    ref_hca, # reference expression profile, a genes x cell type matrix
    df_allele_ATC2, # allele dataframe generated by pileup_and_phase script
    gtf_hg38, # provided upon loading the package
    genetic_map_hg38, # provided upon loading the package
    min_cells = 20,
    t = 1e-3,
    ncores = 20,
    plot = TRUE,
    out_dir = './test'
)
```
# Understanding results
Numbat generates a number of files in the output folder. A comprehensive list can be found [here](#output-descriptions).

The results can be summarized using a `numbat` object:
```
nb = numbat$new(out_dir = './test', i = 2)
```

Now we can visualize the single-cell CNV profiles and lineage relationships:
```
nb$plot_phylo_heatmap(
    clone_bar = TRUE
)
```
![image](https://user-images.githubusercontent.com/13375875/151874913-c75b760b-98f3-4d2f-a080-efb21a67529c.png)

# Output descriptions
The file names are post-fixed with the `i`th iteration of phylogeny optimization.
- `gexp_roll_wide.tsv.gz`: window-smoothed normalized expression profiles of single cells
- `hc.rds`: hierarchical clustering result based on smoothed expression
- `bulk_subtrees_{i}.tsv.gz`: pseudobulk HMM profiles based on subtrees defined by current cell lineage tree
- `segs_consensus_{i}.tsv.gz`: consensus segments from subtree pseudobulk HMMs
- `bulk_clones_{i}.tsv.gz`: pseudobulk HMM profiles based on clones defined by current cell lineage tree
- `bulk_clones_{i}.png`: visualization of clone pseudobulk HMM profiles
- `exp_sc_{i}.tsv.gz`: single-cell expression profiles used for single-cell CNV testing
- `exp_post_{i}.tsv`: single-cell expression posteriors 
- `allele_post_{i}.tsv`: single-cell allele posteriors 
- `joint_post_{i}.tsv`: single-cell joint posteriors 
- `treeUPGMA_{i}.rds`: UPGMA tree
- `treeNJ_{i}.rds`: NJ tree
- `tree_list_{i}.rds`: list of candidate phylogeneies in the maximum likelihood tree search
- `tree_final_{i}.rds`: final tree after simplification
- `mut_graph_{i}.rds`: final mutation history
- `clone_post_{i}.rds`: clone assignment and tumor versus normal classification posteriors
- `bulk_subtrees_{i}.png`: visualization of subtree pseudobulk HMM profiles 
- `bulk_clones_{i}.png`: visualization of clone pseudobulk HMM profiles 
- `panel_{i}.png`: visualization of combined phylogeny and CNV heatmap
