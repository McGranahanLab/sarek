/*
================================================================================
                              PREPARE RECALIBRATION
================================================================================
*/

params.baserecalibrator_options  = [:]
params.gatherbqsrreports_options = [:]

include { GATK4_BASERECALIBRATOR  as BASERECALIBRATOR }  from '../../modules/nf-core/software/gatk4/baserecalibrator'  addParams(options: params.baserecalibrator_options)
include { GATK4_GATHERBQSRREPORTS as GATHERBQSRREPORTS } from '../../modules/nf-core/software/gatk4/gatherbqsrreports' addParams(options: params.gatherbqsrreports_options)

workflow PREPARE_RECALIBRATION {
    take:
        bam_markduplicates // channel: [mandatory] bam_markduplicates
        dbsnp              // channel: [optional]  dbsnp
        dbsnp_tbi          // channel: [optional]  dbsnp_tbi
        dict               // channel: [mandatory] dict
        fai                // channel: [mandatory] fai
        fasta              // channel: [mandatory] fasta
        intervals          // channel: [mandatory] intervals
        known_indels       // channel: [optional]  known_indels
        known_indels_tbi   // channel: [optional]  known_indels_tbi
        step               //   value: [mandatory] starting step

    main:

    bam_baserecalibrator = bam_markduplicates.combine(intervals)
    table_bqsr = Channel.empty()

    if (step in ["mapping", "preparerecalibration"]) {

        BASERECALIBRATOR(bam_baserecalibrator, dbsnp, dbsnp_tbi, dict, fai, fasta, known_indels, known_indels_tbi)
        table_bqsr = BASERECALIBRATOR.out.report

        // STEP 3.5: MERGING RECALIBRATION TABLES
        if (!params.no_intervals) {
            BASERECALIBRATOR.out.report.map{ meta, table ->
                patient = meta.patient
                sample  = meta.sample
                gender  = meta.gender
                status  = meta.status
                [patient, sample, gender, status, table]
            }.groupTuple(by: [0,1]).set{ recaltable }

            recaltable = recaltable.map {
                patient, sample, gender, status, recal ->

                def meta = [:]
                meta.patient = patient
                meta.sample = sample
                meta.gender = gender[0]
                meta.status = status[0]
                meta.id = sample

                [meta, recal]
            }

            GATHERBQSRREPORTS(recaltable)
            table_bqsr = GATHERBQSRREPORTS.out.table
        }

        // Creating TSV files to restart from this step
        table_bqsr.collectFile(storeDir: "${params.outdir}/preprocessing/tsv") { meta, table ->
            patient = meta.patient
            sample  = meta.sample
            gender  = meta.gender
            status  = meta.status
            bam = "${params.outdir}/preprocessing/${sample}/markduplicates/${sample}.md.bam"
            bai = "${params.outdir}/preprocessing/${sample}/markduplicates/${sample}.md.bam.bai"
            ["markduplicates_no_table_${sample}.tsv", "${patient}\t${gender}\t${status}\t${sample}\t${bam}\t${bai}\n"]
        }

        table_bqsr.map { meta, table ->
            patient = meta.patient
            sample  = meta.sample
            gender  = meta.gender
            status  = meta.status
            bam = "${params.outdir}/preprocessing/${sample}/markduplicates/${sample}.md.bam"
            bai = "${params.outdir}/preprocessing/${sample}/markduplicates/${sample}.md.bam.bai"
            "${patient}\t${gender}\t${status}\t${sample}\t${bam}\t${bai}\n"
        }.collectFile(name: 'markduplicates_no_table.tsv', sort: true, storeDir: "${params.outdir}/preprocessing/tsv")
    }

    emit:
        table_bqsr = table_bqsr
}