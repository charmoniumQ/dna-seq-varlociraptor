ruleorder: chm_eval_sample > map_reads

rule chm_eval_sample:
    output:
        bam="resources/chm.bam"
    log:
        "logs/benchmarking/chm-eval-sample.log"
    cache: True
    wrapper:
        "master/bio/benchmark/chm-eval-sample"


rule chm_namesort:
    input:
        "resources/chm.bam"
    output:
        pipe("resources/chm.namesorted.bam")
    params:
        "-n -m 4G"
    log:
        "logs/benchmarking/samtools-namesort.log"
    threads: workflow.cores - 1
    wrapper:
        "0.63.0/bio/samtools/sort"


rule chm_to_fastq:
    input:
        "resources/chm.namesorted.bam"
    output:
        fq1="resources/chm.1.fq.gz",
        fq2="resources/chm.2.fq.gz"
    log:
        "logs/benchmarking/samtools-fastq.log"
    conda:
        "../envs/samtools.yaml"
    shell:
        "samtools fastq {input} -1 {output.fq1} -2 {output.fq2} 2> {log}"

rule chm_eval_kit:
    output:
        directory("resources/benchmarking/chm-eval-kit")
    params:
        # Tag and version must match, see https://github.com/lh3/CHM-eval/releases.
        tag="v0.5",
        version="20180222"
    log:
        "logs/benchmarking/chm-eval-kit.log"
    cache: True
    wrapper:
        "0.63.0/bio/benchmark/chm-eval-kit"


rule chromosome_map:
    input:
        "resources/genome.fasta.fai"
    output:
        "resources/genome.chrmap.txt"
    conda:
        "../envs/awk.yaml"
    shell:
        "awk '{{ print $1,\"chr\"$1 }}' OFS='\t' {input} > {output}"


rule rename_chromosomes:
    input:
        bcf="results/merged-calls/chm.{query}.fdr-controlled.bcf",
        map="resources/genome.chrmap.txt"
    output:
        "benchmarking/{query}.chr-mapped.vcf"
    params:
        targets=",".join(list(map("chr{}".format, range(23))) + ["chrX", "chrY"])
    conda:
        "../envs/bcftools.yaml"
    shell:
        "bcftools annotate --rename-chrs {input.map} {input} | bcftools view --targets {params.targets} > {output}"


rule chm_eval:
    input:
        kit="resources/benchmarking/chm-eval-kit",
        vcf="benchmarking/{query}.chr-mapped.vcf"
    output:
        summary="benchmarking/{query}.summary", # summary statistics
        bed="benchmarking/{query}.err.bed.gz" # bed file with errors
    params:
        extra="",
        build="38"
    log:
        "logs/benchmarking/{query}.chm-eval.log"
    wrapper:
        "0.63.0/bio/benchmark/chm-eval"


#rule plot_benchmark_results:
#    input:
#        expand("benchmarking/{query}.summary", query=config["calling"]["fdr-control"]["events"])
#     output:

