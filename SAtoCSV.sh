#!/bin/bash

# Define paths
RESULTS_DIR="./sa_results/metrics"
OUTPUT_CSV="./results/combined_sa_results.csv"

# Create header for the CSV file
echo "Design,Iteration,Temperature,Recipe,Area,Delay,QoR,Accepted" > "$OUTPUT_CSV"

# Process each design's metrics file
for metrics_file in "$RESULTS_DIR"/*_sa_metrics.txt; do
    # Extract design name from the file name
    design_name=$(basename "$metrics_file" _sa_metrics.txt)
    
    # Skip the header line and process each data line
    tail -n +2 "$metrics_file" | while IFS=',' read -r iteration temperature recipe area delay qor accepted; do
        # Remove quotes from recipe
        recipe=$(echo "$recipe" | tr -d '"' | xargs)
        # Write to the combined CSV file
        echo "$design_name,$iteration,$temperature,\"$recipe\",$area,$delay,$qor,$accepted" >> "$OUTPUT_CSV"
    done
done

echo "Combined results saved to $OUTPUT_CSV"