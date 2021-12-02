# Numbat

<img src="https://user-images.githubusercontent.com/13375875/136429050-609ee367-8d5d-4a63-8fa8-a87171aff01c.png" align="right" width="200">

Numbat is a haplotype-enhanced CNV caller from single-cell transcriptomics data. It integrates gene expression, allele ratio, and haplotype phasing signals from the human population to accurately profile CNVs in single-cells and infer their lineage relationship. 

Numbat can be used to 1. detect allele-specific copy number variations from single-cells 2. differentiate tumor versus normal cells in the tumor microenvironment 3. infer the clonal architecture and evolutionary history of profiled tumors. 

Numbat does not require paired DNA or genotyping data and operates solely on the donor scRNA-data data (for example, 10x Cell Ranger output).

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)

# Prerequisites
Numbat uses cellsnp-lite for generating SNP pileup data and eagle2 for phasing. Please follow their installation instructions and make sure their binary executables can be found in your $PATH.

1. [cellsnp-lite](https://github.com/single-cell-genetics/cellsnp-lite)
2. [eagle2](https://alkesgroup.broadinstitute.org/Eagle/)

Additionally, Numbat needs a common SNP VCF and phasing reference panel. You can use the 1000 Genome reference below:

3. 1000G SNP reference file 
```
wget https://sourceforge.net/projects/cellsnp/files/SNPlist/genome1K.phase3.SNP_AF5e2.chr1toX.hg38.vcf.gz
```
4. 1000G Reference Panel
```
wget http://pklab.med.harvard.edu/teng/data/1000G.zip
```

# Installation
Install the Numbat R package via:
```
git clone https://github.com/kharchenkolab/Numbat.git
```
Within R,
```
devtools::install_local("./Numbat")
```

# Usage
1. Run the preprocessing script (`pileup_and_phase.r`): collect allele data and phase SNPs
```
usage: pileup_and_phase.r [-h] [--label LABEL] [--samples SAMPLES]
                          [--bams BAMS] [--barcodes BARCODES] [--gmap GMAP]
                          [--snpvcf SNPVCF] [--paneldir PANELDIR]
                          [--outdir OUTDIR] [--ncores NCORES]

Run SNP pileup and phasing with 1000G

optional arguments:
  -h, --help           show this help message and exit
  --label LABEL        individual label
  --samples SAMPLES    sample names, comma delimited
  --bams BAMS          bam files, one per sample, comma delimited
  --barcodes BARCODES  cell barcodes, one per sample, comma delimited
  --gmap GMAP          path to genetic map provided by Eagle2
  --snpvcf SNPVCF      SNP VCF for pileup
  --paneldir PANELDIR  directory to phasing reference panel (BCF files)
  --outdir OUTDIR      output directory
  --ncores NCORES      number of cores
```

2. Run Numbat
In this example (ATC2 from Gao et al), the gene expression count matrix and allele dataframe are already prepared for you.
```
library(numbat)

# run
out = numbat_subclone(
    count_mat_test, # gene x cell raw UMI count matrix 
    ref_hca, # reference expression profile, a genes x cell type matrix
    df_test, # allele dataframe generated by pileup_and_phase script
    gtf_transcript,
    genetic_map_hg38,
    min_cells = 20,
    t = 1e-6,
    ncores = 20,
    init_k = 3,
    max_cost = 150,
    out_dir = glue('~/results/test')
)
```
3. visualize results
Numbat generates a number of files in the output folder. The main results can be loaded by this function:
```res = fetch_results(out_dir, i = 2)```

Now we can visualize the single-cell CNV and lineage relationships:
```
plot_sc_joint(
    res$gtree,
    res$joint_post,
    res$segs_consensus,
    tip_length = 2,
    branch_width = 0.2,
    size = 0.3
) +
ggtitle('ATC2')
```
![image](https://user-images.githubusercontent.com/13375875/144479138-0cf007cd-a979-4910-835d-fd20b920ba67.png)


