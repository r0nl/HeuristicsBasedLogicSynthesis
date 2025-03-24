#!/bin/bash

# Define paths
ABC_PATH="./abc"
DESIGNS_DIR="./bobs"
OUTPUT_DIR="./results"
OUTPUT_FILE="$OUTPUT_DIR/initial_stats.txt"

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Remove existing output file if it exists
rm -f $OUTPUT_FILE

# Function to get design statistics
get_design_stats() {
    local design=$1
    
    # Run ABC with NAND library and capture output
    # Using technology mapping with the library
    output=$($ABC_PATH -c "source -s abc.rc; read_lib nangate_45.lib; read_bench $DESIGNS_DIR/$design; b; map; ps;")
    
    # Extract area (AND nodes), delay (level), and calculate QoR
    area=$(echo "$output" | grep -oP 'area\s*=\s*\K[0-9.]+')
    delay=$(echo "$output" | grep -oP 'delay\s*=\s*\K[0-9.]+')
    
    # If area or delay contain decimal points, truncate to integers for QoR calculation
    area_int=${area%.*}
    delay_int=${delay%.*}
    qor=$((area_int * delay_int))
    
    echo "$design,$area,$delay,$qor"
}

# List of designs
DESIGNS=("simple_spi_orig.bench" "pci_orig.bench" "aes_secworks_orig.bench")

# Write header to output file
echo "Design,Area,Delay,QoR" > $OUTPUT_FILE

# Process each design
for design in "${DESIGNS[@]}"; do
    stats=$(get_design_stats $design)
    echo $stats >> $OUTPUT_FILE
done

echo "Initial statistics saved to $OUTPUT_FILE"
