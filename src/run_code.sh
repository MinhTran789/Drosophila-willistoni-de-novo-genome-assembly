# Run commands to launch respective jobs on the DNAnexus platform

# trimmomatic qc
dx run applet-GY7vjBQ0Gp8VybPXPX6qQ9Q2 --priority high -j '{
    "R1": {
        "$dnanexus_link": "file-GY7jf080Gp8QgVb95P29ZPYP"
    },
    "R2": {
        "$dnanexus_link": "file-GY7jpBQ0Gp8X6KKGjkBb5BfJ"
    }
}'

# platanus assembly
dx run applet-GY851F00Gp8f8gKqk231FvyX --priority high -j '{
    "paired_forward_reads": {
        "$dnanexus_link": "file-GY7xFz00xZ1kQv78Yxjkq3vp"
    },
    "paired_reverse_reads": {
        "$dnanexus_link": "file-GY7xFz00xZ1X7YjjF70Pz7YY"
    },
    "unpaired_forward_reads": {
        "$dnanexus_link": "file-GY7xFz00xZ1pV54x6kbkxx4Z"
    },
    "unpaired_reverse_reads": {
        "$dnanexus_link": "file-GY7xFz00xZ1zZKPqYGKygfBz"
    }
}'

# Canu assembly
dx run applet-GY90pZ80Gp8qxqKBk9kqjbbX --delay-workspace-destruction --priority high -j '{
    "pacbio_fastq": {
        "$dnanexus_link": "file-GY7kKgQ0Gp8qQkKjGQ8z12k3"
    }
}'

# quickmerge
dx run applet-GYFV4F00Gp8qJ4b6fZbjK45B --delay-workspace-destruction --priority high -j '{
    "canu_assembled_reads": {
        "$dnanexus_link": "file-GYB6y98094BbpjVP0x75Pb6G"
    },
    "platanus_assembled_reads": {
        "$dnanexus_link": "file-GY8fPFQ0v58yYJ4GgkqxJ5y2"
    }
}'
