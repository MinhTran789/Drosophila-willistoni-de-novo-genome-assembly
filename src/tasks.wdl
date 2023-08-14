version 1.0

task trimmomatic_qc {
  input {
    File R1
    File R2
  }

  command {
    trimmomatic PE \
      -threads 8 \
      ${R1} ${R2} \
      -baseout Dwil_illmn_trimm.fq.gz \
      ILLUMINACLIP:/Trimmomatic-0.39/adapters/TruSeq2-SE.fa:2:30:10 \
      SLIDINGWINDOW:4:15 MINLEN:20
  }

  output {
    File paired_forward_reads = "Dwil_illmn_trimm_1P.fq.gz"
    File paired_reverse_reads = "Dwil_illmn_trimm_2P.fq.gz"
    File unpaired_forward_reads = "Dwil_illmn_trimm_1U.fq.gz"
    File unpaired_reverse_reads = "Dwil_illmn_trimm_2U.fq.gz"
  }

  runtime {
    docker: "staphb/trimmomatic:latest"
    dx_instance_type: "mem1_ssd1_v2_x8"
    dx_timeout: "96H"
    dx_access: object {
      network: ["*"],
      developer: true
    }
  }
}


task platanus_assembly {
  input {
    File paired_forward_reads
    File paired_reverse_reads
    File unpaired_forward_reads
    File unpaired_reverse_reads
  }
  
  command {

    echo "Unzipping fastq files because Platanus cannot recognize compressed FASTQ!!!"
    mv ${paired_forward_reads} input_paired_forward_reads.gz && gzip -d input_paired_forward_reads.gz
    mv ${paired_reverse_reads} input_paired_reverse_reads.gz && gzip -d input_paired_reverse_reads.gz
    mv ${unpaired_forward_reads} input_unpaired_forward_reads.gz && gzip -d input_unpaired_forward_reads.gz
    mv ${unpaired_reverse_reads} input_unpaired_reverse_reads.gz && gzip -d input_unpaired_reverse_reads.gz

    # -m is memory limit for making kmer distribution (GB, >=1, default 16), author set to 300GB
    Platanus assemble \
      -o platanus_Dwil \
      -f input_* \
      -t 16 -m 64 >& platanusAssemRun1.log
  }
  
  output {
    Array[File] result = glob("platanus_Dwil*") 
    File log = "platanusAssemRun1.log"
  }

  runtime {
    docker: "dx://file-GY6Vbzj0Gp8fzG098V7z78kv" # Platanus image built from https://github.com/cmonjeau/docker-platanus
    dx_instance_type: "mem3_ssd1_v2_x16"
  }
}


task canu_assembly {
  input {
    File pacbio_fastq
  }

  command {
    
    mkdir canu_correct
    mkdir canu_assemble

    canu -correct \
      -d canu_correct \
      -p Dwil \
      minReadLength=1000 minOverlapLength=500 rawErrorRate=0.3 correctedErrorRate=0.045 genomeSize=250m useGrid=false \
      -pacbio-raw ${pacbio_fastq}
    
    canu -assemble \
      -d canu_assemble \
      -p Dwil \
      genomeSize=250m \
      -pacbio-corrected canu_correct/Dwil.correctedReads.fasta.gz \
      minOverlapLength=500 rawErrorRate=0.3 correctedErrorRate=0.045 genomeSize=250m useGrid=false
  }

  output {
    Array[File] canu_correct_result = glob("canu_correct/Dwil*")
    Array[File] canu_assemble_result = glob("canu_assemble/Dwil*")
  }

  runtime {
    docker: "biocontainers/canu:v1.8dfsg-2-deb_cv1"
    dx_instance_type: "mem1_ssd1_v2_x16"
  }
}


task quickmerge {
  input {
    File platanus_assembled_reads # the platanus_Dwil_contig.fa file from Platanus
    File canu_assembled_reads # the Dwil.contigs.fasta file from Canu
    File quickmerge_docker_image = "dx://file-GYBp7Bj0Gp8YK0P9z6YKB7kz"
    File nummer4_docker_image = "dx://file-GYBqpg80Gp8vy07J5Y8q46jb"
  }

  command {
    docker load -i ${quickmerge_docker_image}
    docker load -i ${nummer4_docker_image}
    
    mv ${platanus_assembled_reads} platanus_input.fasta
    mv ${canu_assembled_reads} canu_input.fasta

    echo "Running 'merge_wrapper.py'"
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      quay.io/biocontainers/quickmerge:0.3--pl5321hdbdd923_5 \
      merge_wrapper.py --clean_only platanus_input.fasta canu_input.fasta
    echo "Finished running 'merge_wrapper.py'"

    mv self_oneline.fa canuDwil.qmFormat.fa 
    mv hybrid_oneline.fa platanus_Dwil_contig.qmFormat.fa
    
    echo "Running 'nucmer'"
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      staphb/mummer:4.0.0 \
      nucmer -t 16 -l 100 -p qm2 platanus_Dwil_contig.qmFormat.fa canuDwil.qmFormat.fa
    
    echo "Finished running 'nucmer'"

    echo "Running 'delta-filter'"
    
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      staphb/mummer:4.0.0 \
      delta-filter -i 95 -r -q qm2.delta > qm2.rq.delta 

    echo "Finished running 'delta-filter'"

    echo "Running 'quickmerge'"
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      quay.io/biocontainers/quickmerge:0.3--pl5321hdbdd923_5 \
      quickmerge -d qm2.rq.delta -q platanus_Dwil_contig.qmFormat.fa -r canuDwil.qmFormat.fa -hco 5.0 -c 1.5 -l 1772525 -ml 5000 -p result
    
    mv merged_result.fasta qm2.def.fasta

    echo "Done!"
  }

  output {
    File merged_assembly = "qm2.def.fasta"
    File delta_filter_result = "qm2.rq.delta"
  }

  runtime {
    dx_instance_type: "mem1_ssd1_v2_x16"
  }
}

task only_quickmerge {
  input {
    File qm2_rq_delta = "dx://file-GYG8ZbQ0jYZ62bj13JYvX9G3"
    File platanus_Dwil_contig_qmFormat = "dx://file-GYG8BKQ0b4PB5493jvKXZ51G"
    File canuDwil_qmFormat = "dx://file-GYG8BKQ0b4PGq9JX77yJjz0K"
    File quickmerge_docker_image = "dx://file-GYBp7Bj0Gp8YK0P9z6YKB7kz"
  }

  command {
    docker load -i ${quickmerge_docker_image}

    echo "Running 'quickmerge'"
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      quay.io/biocontainers/quickmerge:0.3--pl5321hdbdd923_5 \
      quickmerge -d ${qm2_rq_delta} -q ${platanus_Dwil_contig_qmFormat} -r ${canuDwil_qmFormat} -hco 5.0 -c 1.5 -l 1772525 -ml 5000 -p result
    
    mv merged_result.fasta qm2.def.fasta

    echo "Done!"
  }

  output {
    File merged_assembly = "qm2.def.fasta"
  }

  runtime {
    dx_instance_type: "mem1_ssd1_v2_x16"
  }
}


task delta_filter {
  input {
    File platanus_assembled_reads # the platanus_Dwil_contig.fa file from Platanus
    File canu_assembled_reads # the Dwil.contigs.fasta file from Canu
    File quickmerge_docker_image = "dx://file-GYBp7Bj0Gp8YK0P9z6YKB7kz"
    File nummer4_docker_image = "dx://file-GYBqpg80Gp8vy07J5Y8q46jb"
  }

  command {
    docker load -i ${quickmerge_docker_image}
    docker load -i ${nummer4_docker_image}
    
    mv ${platanus_assembled_reads} platanus_input.fasta
    mv ${canu_assembled_reads} canu_input.fasta

    echo "Running 'merge_wrapper.py'"
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      quay.io/biocontainers/quickmerge:0.3--pl5321hdbdd923_5 \
      merge_wrapper.py --clean_only platanus_input.fasta canu_input.fasta
    echo "Finished running 'merge_wrapper.py'"

    mv self_oneline.fa canuDwil.qmFormat.fa 
    mv hybrid_oneline.fa platanus_Dwil_contig.qmFormat.fa
    
    echo "Running 'nucmer'"
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      staphb/mummer:4.0.0 \
      nucmer -t 16 -l 100 -p qm2 platanus_Dwil_contig.qmFormat.fa canuDwil.qmFormat.fa
    
    echo "Finished running 'nucmer'"

    echo "Running 'delta-filter'"
    
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      staphb/mummer:4.0.0 \
      delta-filter -i 95 -r -q qm2.delta > qm2.rq.delta 

    echo "Finished running 'delta-filter'"

    echo "Done!"
  
  }

  output {
    File delta_filter_result = "qm2.rq.delta"
  }

  runtime {
    dx_instance_type: "mem1_ssd1_v2_x16"
  }
}

task merge_wrapper {
  input {
    File platanus_assembled_reads # the platanus_Dwil_contig.fa file from Platanus
    File canu_assembled_reads # the Dwil.contigs.fasta file from Canu
    File quickmerge_docker_image = "dx://file-GYBp7Bj0Gp8YK0P9z6YKB7kz"
  }

  command {
    docker load -i ${quickmerge_docker_image}
    
    mv ${platanus_assembled_reads} platanus_input.fasta
    mv ${canu_assembled_reads} canu_input.fasta

    echo "Running 'merge_wrapper.py'"
    docker run \
      -v $PWD:/home/dnanexus \
      -w /home/dnanexus \
      quay.io/biocontainers/quickmerge:0.3--pl5321hdbdd923_5 \
      merge_wrapper.py --clean_only platanus_input.fasta canu_input.fasta
    echo "Finished running 'merge_wrapper.py'"

    mv self_oneline.fa canuDwil.qmFormat.fa 
    mv hybrid_oneline.fa platanus_Dwil_contig.qmFormat.fa

    echo "Done!"
  }

  output {
    File canuDwil_qmFormat = "canuDwil.qmFormat.fa"
    File platanus_Dwil_contig_qmFormat = "platanus_Dwil_contig.qmFormat.fa"
  }

  runtime {
    dx_instance_type: "mem1_ssd1_v2_x16"
  }
}

task pilon_polishing {
  input {
    File merged_assembly_file # the qm2.def.fasta from quickmerge 
    File paired_forward_reads # trimmed Illumina reads from trimmomatic
    File paired_reverse_reads # trimmed Illumina reads from trimmomatic
    File interleave_docker_image = "dx://file-GYFk4BQ0Gp8ky10vv5KF6g95"
    File bwa_samtools_docker_image = "dx://file-GYFk4F00Gp8gxkK52k1PqGvG"
    File pilon_docker_image = "dx://file-GYFkKbQ0Gp8ZPqggv252B78Y"
  }

  command {
    mkdir trimmed_reads
    mkdir reads
    mkdir pilon_output

    mv ${merged_assembly_file} genome/
    mv ${paired_forward_reads} trimmed_reads/read1.fastq.gz
    mv ${paired_reverse_reads} trimmed_reads/read2.fastq.gz
    
    docker load -i ${interleave_docker_image}
    docker load -i ${bwa_samtools_docker_image}
    docker load -i ${pilon_docker_image}
    echo "All docker images loaded."

    echo "Running interleave"
    # interleave the paired fastq files
    docker run \
      -v trimmed_reads:/data \
      -w /data \
      erictdawson/interleave-fastq:latest \
        interleave-fastq read1.fastq.gz read2.fastq.gz | gzip > Dwil_illmn_trimm_interleaved.fastq.gz
    echo "Finished running interleave"

    mv trimmed_reads/Dwil_illmn_trimm_interleaved.fastq.gz reads/
    
    echo "Setting variables and creating run scripts"
    genome=${merged_assembly_file}
    reads=$PWD/reads/Dwil_illmn_trimm_interleaved.fastq.gz
    
    iter=1
    echo -e "bwa index $genome\nbwa mem -t 64 $genome -p $reads | samtools view -@ 64 -bS | samtools sort -@ 64 -o pilon$iter.bam\nsamtools index -@ 64 pilon$iter.bam" > bwa$iter.sh
    echo -e "java -jar /pilon/pilon.jar --genome $genome --frags pilon$iter.bam --output pilon_improved$iter --outdir pilon_output --changes" > pilon$iter.sh
    
    echo "Running BWA and Samtools"
    docker run \
      -v $PWD:/home/dnanexus/ \
      -w /home/dnanexus/ \
      -e genome=$genome \
      -e reads=$reads \
      -e iter=$iter \
      dukegcb/bwa-samtools:latest bwa$iter.sh
    echo "Finished running BWA and Samtools"
    
    echo "Running Pilon"
    docker run \
      -v $PWD:/home/dnanexus/ \
      -w /home/dnanexus/ \
      -e genome=$genome \
      -e iter=$iter \
      staphb/pilon:latest pilon$iter.sh
    echo "Finished running Pilon"
    echo "Done!"
  }

  output {
    Array[File] pilon_result = glob("pilon_output/pilon_improved*")
  }

  runtime {
    dx_instance_type: "mem3_ssd1_v2_x32"
  }
}
