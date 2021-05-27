# slurm_scripts

Place both read files and the index fasta in the same folder as the script.
Be sure your terminal is in this folder (using the cd command).

Open and edit the pipeline.sh script with the following:
    #SBATCH --mail-user=[YOUR_USER_ID_HERE]@umn.edu
    read1 filename
    read2 filename
    index.fasta filename

To run pipeline.sh:
  `sbatch pipeline.sh`

Check job status using sacct -j [job_id].

It should take around ~20 mins to run.
