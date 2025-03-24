#!/bin/bash

# Define paths
ABC_PATH="./abc"
DESIGNS_DIR="./bobs"
RECIPES_DIR="./recipes"
OUTPUT_DIR="./results"

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Define designs
DESIGNS=("simple_spi_orig.bench" "pci_orig.bench" "aes_secworks_orig.bench")
DESIGN_NAMES=("simple_spi_orig.bench" "pci_orig.bench" "aes_secworks_orig.bench")

# Ensure output files are overwritten at the start
for design_name in "${DESIGN_NAMES[@]}"; do
    echo "Design,Recipe_Number,Final_Area,Final_Delay,Final_QoR" > "$OUTPUT_DIR/${design_name}_metrics.txt"
done

# Function to run ABC with a given design and recipe
run_abc_recipe() {
    local design=$1
    local recipe=$2

    # Create ABC script file
    echo "source -s abc.rc;" > abc_script.txt
    echo "read_lib nangate_45.lib;" >> abc_script.txt
    echo "read_bench $DESIGNS_DIR/$design;" >> abc_script.txt

    # Add each command from the recipe
    for cmd in $recipe; do
        if [ ! -z "$cmd" ]; then
            echo "$cmd" >> abc_script.txt
        fi
    done

    # Add command to print statistics
    echo "map;" >> abc_script.txt
    echo "ps;" >> abc_script.txt

    # Run ABC and capture output
    output=$($ABC_PATH -f abc_script.txt 2>&1)

    # Extract and nodes (area), level (delay)
    area=$(echo "$output" | grep -oP 'area\s*=\s*\K[0-9.]+')
    delay=$(echo "$output" | grep -oP 'delay\s*=\s*\K[0-9.]+')

    if [ -z "$area" ] || [ -z "$delay" ]; then
        area=${area:-"NA"}
        delay=${delay:-"NA"}
        echo "Warning: Could not extract area or delay information for design $design" >&2
    fi

    # Calculate QoR (area * delay)
    # If area or delay contain decimal points, truncate to integers for QoR calculation
    area_int=${area%.*}
    delay_int=${delay%.*}
    qor=$((area_int * delay_int))

    echo "$area|$delay|$qor"
}

# Process each design
for i in "${!DESIGNS[@]}"; do
    design=${DESIGNS[$i]}
    design_name=${DESIGN_NAMES[$i]}
    
    recipe_file="$RECIPES_DIR/${design_name}_recipes.txt"
    output_file="$OUTPUT_DIR/${design_name}_metrics.txt"
    
    echo "Processing recipes for $design_name..."
    
    if [ ! -f "$recipe_file" ]; then
        echo "Recipe file not found: $recipe_file"
        continue
    fi
    
    # Read recipes one by one
    recipe_num=1
    while IFS= read -r recipe; do
        echo "  Processing recipe $recipe_num for $design_name"
        
        # Run ABC with the recipe and get metrics
        metrics=$(run_abc_recipe "$design" "$recipe")
        IFS='|' read -ra METRICS <<< "$metrics"
        
        final_area=${METRICS[0]}
        final_delay=${METRICS[1]}
        final_qor=${METRICS[2]}
        
        # Store results in the output file
        echo "$design_name,$recipe_num,$final_area,$final_delay,$final_qor" >> "$output_file"
        
        ((recipe_num++))
    done < "$recipe_file"
    
    echo "Completed processing for $design_name. Results saved to $output_file"
done

echo "All recipes processed. Results saved to $OUTPUT_DIR directory."
