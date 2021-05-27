#!/bin/bash
#SBATCH --nodes=1
#SBATCH --job-name="pipeline_job"
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128
#SBATCH --output=pipeline_job.out
#SBATCH --error=pipeline_job.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=soisa001@umn.edu
#SBATCH --time=2:00:00
#SBATCH -p amdsmall,amdlarge,amd512,amd2tb



# File Name Entry --------------------------
# Replace read1 and read2 with read filenames
read1="AMS4082_S53_L001_R1_001.fastq.gz"
read2="AMS4082_S53_L001_R1_001.fastq.gz"

# Replace reference_fasta appropriately
reference_fasta="C_albicans_SC5314_A21_current_chromosomes.fasta"
# -------------------------------------------

# Load modules
module load trimmomatic/0.39
module load bwa
module load samtools
module load picard
module load gatk/3.7.0
trimmomatic="java -jar /panfs/roc/msisoft/trimmomatic/0.39/trimmomatic.jar"
samtools="/panfs/roc/msisoft/samtools/1.7/bin/samtools"
gatk="java -jar /panfs/roc/msisoft/gatk/3.7.0/GenomeAnalysisTK.jar"

# String parsing
strain=$(echo $read1| cut -d'_' -f 1) # e.g. "AMS4046"
filename=$(echo $reference_fasta| cut -d'.' -f 1)
reference_dict=$(echo $filename).dict # e.g. "C_albicans_SC5314_A21_current_chromosomes.dict"

# Generates indices
bwa index -a bwtsw ./${reference_fasta}
java -jar /panfs/roc/msisoft/picard/2.18.16/picard.jar CreateSequenceDictionary R=./${reference_fasta} O=${reference_dict}
$samtools faidx ./${reference_fasta}


# Trim using trimmomatic
$trimmomatic PE -threads 128 -phred33 -trimlog ${strain_filepath}.trimlog ${read1} ${read2} ${strain}_trimpairedr1.fastq.gz ${strain}_trimunpairedr1.fastq.gz ${strain}_trimpairedr2.fastq.gz ${strain}_trimunpairedr2.fastq.gz LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36 TOPHRED33

# Align to reference fasta using BWA MEM
bwa mem -t 128 -R "@RG\tID:Calbicans\tPL:ILLUMINA\tPM:MiSeq\tSM:${strain}" ./${reference_fasta} ./${read1} ./${read2} > ${strain}_trimmed_bwa.sam

# Samtools sort, index, remove duplicates, and reindex
$samtools view -bS -o ${strain}_trimmed_bwa.bam ${strain}_trimmed_bwa.sam
$samtools flagstat ${strain}_trimmed_bwa.bam > ${strain}_trimmed_bwa.stdout
$samtools sort ${strain}_trimmed_bwa.bam -o ${strain}_trimmed_bwa_sorted.bam
$samtools index ${strain}_trimmed_bwa_sorted.bam
$samtools rmdup ${strain}_trimmed_bwa_sorted.bam ${strain}_trimmed_bwa_sorted_rmdup.bam
$samtools index ${strain}_trimmed_bwa_sorted_rmdup.bam

# Generates known/predicted indels and realigns using GATK v3
$gatk -T RealignerTargetCreator -R ${reference_fasta} -I ${strain}_trimmed_bwa_sorted_rmdup.bam -o ${strain}_trimmed_bwa_sorted_rmdup.bam.intervals
$gatk -T IndelRealigner -model USE_READS -targetIntervals ${strain}_trimmed_bwa_sorted_rmdup.bam.intervals -R ${reference_fasta} -I ${strain}_trimmed_bwa_sorted_rmdup.bam -o ${strain}_trimmed_bwa_sorted_rmdup_realigned.bam
