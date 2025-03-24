#!/bin/bash

# Define paths
RESULTS_DIR="./mc_results/metrics"
OUTPUT_CSV="./results/combined_mc_results.csv"

# Create header for the CSV file
echo "Design,Sample,Recipe,Area,Delay,QoR" > "$OUTPUT_CSV"

# Process each design's metrics file
for metrics_file in "$RESULTS_DIR"/*_mc_metrics.txt; do
    # Extract design name from the file name
    design_name=$(basename "$metrics_file" _mc_metrics.txt)
    
    # Skip the header line and process each data line
    tail -n +2 "$metrics_file" | while IFS=',' read -r sample recipe area delay qor; do
        # Remove quotes from recipe
        recipe=$(echo "$recipe" | tr -d '"')
        # Write to the combined CSV file
        echo "$design_name,$sample,\"$recipe\",$area,$delay,$qor" >> "$OUTPUT_CSV"
    done
done

echo "Combined results saved to $OUTPUT_CSV"
