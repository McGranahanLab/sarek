 
INPUT=$1
DIRNAME=`dirname "$INPUT"`

# should load Nextflow and Singularity prior to submission

nextflow run /SAN/colcc/TX100_WGS_sarek/src/sarek/main.nf --input $INPUT -profile singularity -c /SAN/colcc/TX100_WGS_sarek/src/sarek/ucl.conf –-work_dir $DIRNAME/working --outdir $DIRNAME/results -resume --genome GRCh38 -qs 500 --igenomes_base /SAN/colcc/TX100_WGS_raw/wgs/data/references/ --tools HaplotypeCaller,Manta,Strelka,ASCAT,Mutect2 --skip_qc FastQC,bamQC,BCFtools