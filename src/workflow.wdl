version 1.0

workflow genome_assembly {
  input {
    File illumina_read1 # paired illumina read 1
    File illumina_read2 # paired illumina read 2
    File pacbio_read # pacbio read
  }
  
  call trimmomatic_qc {
    input:
      R1 = illumina_read1
      R2 = illumina_read2
  }

  call platanus_assembly {
    input:
      paired_forward_reads = trimmomatic_qc.paired_forward_reads
      paired_reverse_reads = trimmomatic_qc.paired_forward_reads
      unpaired_forward_reads = trimmomatic_qc.paired_forward_reads
      unpaired_reverse_reads = trimmomatic_qc.paired_forward_reads
  }

  call canu_assembly {
    input:
      pacbio_fastq = pacbio_read
  }
  
  # Find the index of the platanus_Dwil_contig.fa 
  Int platanus_contig_file_index = indexof(platanus_assembly.result, "platanus_Dwil_contig.fa")
  
  # Find the index of the Dwil.contigs.fasta from Canu
  Int canu_contig_file_index = indexof(canu_assembly.result, "Dwil.contigs.fasta")
  
  call quickmerge {
    input:
      platanus_assembled_reads = platanus_assembly.result[platanus_contig_file_index]
      canu_assembled_reads = canu_assembly.result[canu_contig_file_index]
  }

  call pilon_polishing {
    input:
      merged_assembly_file = quickmerge.merged_assembly
      paired_forward_reads = trimmomatic_qc.paired_forward_reads
      paired_reverse_reads = trimmomatic_qc.paired_forward_reads
  }

  output {
    Array[File] assembled_genome = pilon_polishing.pilon_result
  }
}
