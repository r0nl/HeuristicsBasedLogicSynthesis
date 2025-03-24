#!/bin/bash

# Define paths
ABC_PATH="./abc"
DESIGNS_DIR="./bobs"
OUTPUT_DIR="./mc_results"
RECIPES_DIR="$OUTPUT_DIR/recipes"
METRICS_DIR="$OUTPUT_DIR/metrics"

# Create output directories
mkdir -p $OUTPUT_DIR $RECIPES_DIR $METRICS_DIR

# Select designs
DESIGNS=("simple_spi_orig.bench" "pci_orig.bench" "aes_secworks_orig.bench")

# Define AIG simplification tools and their mappings
declare -A tool_map
tool_map[1]="b;"
tool_map[2]="rw;"
tool_map[3]="rf;"
tool_map[4]="rs;"
tool_map[5]="st;"
tool_map[6]="rwz;"
tool_map[7]="f;"
tool_map[8]="rfz;"

# Monte Carlo settings
NUM_SAMPLES=500
MAX_ITERATIONS=20

# Function to evaluate a recipe using ABC
evaluate_recipe() {
    local design=$1
    local recipe=$2
    
    # Create ABC script file
    echo "source -s abc.rc;" > abc_script.txt
    echo "read_lib nangate_45.lib;" >> abc_script.txt
    echo "read_bench $DESIGNS_DIR/$design;" >> abc_script.txt
    
    # Add each command from the recipe
    for cmd in $recipe; do
        echo "$cmd" >> abc_script.txt
    done
    
    # Add mapping and print stats
    echo "map;" >> abc_script.txt
    echo "ps;" >> abc_script.txt
    
    # Run ABC and capture output
    output=$($ABC_PATH -f abc_script.txt 2>&1)
    
    # Extract area and delay
    area=$(echo "$output" | grep -oP 'area\s*=\s*\K[0-9.]+')
    delay=$(echo "$output" | grep -oP 'delay\s*=\s*\K[0-9.]+')
    
    # Calculate QoR
    area_int=${area%.*}
    delay_int=${delay%.*}
    qor=$((area_int * delay_int))
    
    echo "$area|$delay|$qor"
}

# Process each design
for design in "${DESIGNS[@]}"; do
    design_name=$(basename $design .bench)
    echo "Processing $design_name with Monte Carlo..."
    
    # Initialize tracking of best recipe
    best_qor=999999999
    best_area=999999999
    best_delay=999999999
    best_recipe=""
    
    # Create metrics output file
    metrics_file="$METRICS_DIR/${design_name}_mc_metrics.txt"
    echo "Sample,Recipe,Area,Delay,QoR" > "$metrics_file"
    
    # Create recipes output file
    recipes_file="$RECIPES_DIR/${design_name}_mc_recipes.txt"
    > "$recipes_file"
    
    # Perform Monte Carlo sampling
    for ((sample=1; sample<=NUM_SAMPLES; sample++)); do
        # Generate random recipe
		# Randomly choose between balance or strash as first command
		if [ $((RANDOM % 2)) -eq 0 ]; then
		    recipe="b;" # Start with balance
		else
		    recipe="st;" # Start with strash
		fi

    	for ((i=2; i<=MAX_ITERATIONS; i++)); do
            tool_id=$((1 + RANDOM % 8))
            recipe="$recipe ${tool_map[$tool_id]}"
        done
        
        # Evaluate recipe
        echo "Sample $sample: Evaluating recipe..."
        metrics=$(evaluate_recipe "$design" "$recipe")
        IFS='|' read -ra METRICS <<< "$metrics"
        
        area=${METRICS[0]}
        delay=${METRICS[1]}
        qor=${METRICS[2]}
        
        # Record recipe and metrics
        echo "$sample,\"$recipe\",$area,$delay,$qor" >> "$metrics_file"
        echo "$recipe" >> "$recipes_file"
        
        # Update best recipe if better (inside the sample loop)
        if (( qor < best_qor )); then
            best_qor=$qor
            best_area=$area
            best_delay=$delay
            best_recipe="$recipe"
            echo "New best recipe found! Area: $best_area, Delay: $best_delay, QoR: $best_qor"
        fi

    done
    
    echo "Best Monte Carlo recipe for $design_name:"
    echo "$best_recipe"
    echo "Area: $best_area, Delay: $best_delay, QoR: $best_qor"
    echo ""
done

echo "Monte Carlo optimization completed. Results saved to $OUTPUT_DIR directory."
