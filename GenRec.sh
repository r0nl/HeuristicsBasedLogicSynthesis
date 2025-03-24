#!/bin/bash

# Define paths
OUTPUT_DIR="./recipes"

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

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


# Function to generate a random recipe of size 20
generate_random_recipe() {
    # Randomly choose between balance or strash as first command
    if [ $((RANDOM % 2)) -eq 0 ]; then
        local recipe="b;" # Start with balance
    else
        local recipe="st;" # Start with strash
    fi

    for ((i=2; i<=20; i++)); do # Start from 2 since we already have first command
        # Generate a random number between 1 and 10
        tool_id=$((1 + RANDOM % 8))
        
        # Add the tool to the recipe
        recipe="$recipe ${tool_map[$tool_id]}"
    done
    
    echo "$recipe"
}


# Generate 500 recipes for each design
for design in "${DESIGNS[@]}"; do
    echo "Generating recipes for $design..."
    
    # Remove existing recipe file if it exists
    recipe_file="$OUTPUT_DIR/${design}_recipes.txt"
    rm -f "$recipe_file"
    
    # Generate 500 recipes
    for ((r=1; r<=500; r++)); do
        recipe=$(generate_random_recipe)
        echo "$recipe" >> "$recipe_file"
    done
    
    echo "Generated 500 recipes for $design in $recipe_file"
done

echo "Recipe generation completed. Results saved to $OUTPUT_DIR directory."
