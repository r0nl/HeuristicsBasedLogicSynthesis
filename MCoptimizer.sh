#!/bin/bash

# Define paths
ABC_PATH="./abc"
DESIGNS_DIR="./bobs"
RECIPES_DIR="./recipes"
OUTPUT_DIR="./results"
FINAL_CSV="$OUTPUT_DIR/combined_mc_results.csv"
BEST_RECIPES="$OUTPUT_DIR/best_recipes.txt"

# Create output directories
mkdir -p "$OUTPUT_DIR"

# Select designs
DESIGNS=("simple_spi_orig.bench" "pci_orig.bench" "aes_secworks_orig.bench")

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
    qor=$(echo "$area_int * $delay_int" | bc)
    
    echo "$area|$delay|$qor"
}

# Initialize CSV file with header
echo "Design,Sample,Recipe,Area,Delay,QoR" > "$FINAL_CSV"

# Initialize best recipes file
> "$BEST_RECIPES"

# Process each design
for design in "${DESIGNS[@]}"; do
    design_name=$(basename "$design" .bench)
    echo "Processing $design_name with Monte Carlo..."
    
    # Check if recipe file exists
    recipe_file="$RECIPES_DIR/${design}_recipes.txt"
    if [ ! -f "$recipe_file" ]; then
        echo "Error: Recipe file $recipe_file not found!"
        continue
    fi
    
    # Read recipes into an array
    mapfile -t recipes < "$recipe_file"
    num_recipes=${#recipes[@]}
    
    echo "Found $num_recipes recipes for $design_name"
    
    # Initialize arrays to track top 3 best recipes
    declare -a best_qors=( 999999999 999999999 999999999 )
    declare -a best_areas=( 999999999 999999999 999999999 )
    declare -a best_delays=( 999999999 999999999 999999999 )
    declare -a best_recipes=( "" "" "" )
    
    # Process each recipe
    for ((i=0; i<num_recipes; i++)); do
        sample=$((i+1))
        recipe="${recipes[$i]}"
        
        # Evaluate recipe
        echo "Sample $sample: Evaluating recipe..."
        metrics=$(evaluate_recipe "$design" "$recipe")
        IFS='|' read -ra METRICS <<< "$metrics"
        
        area=${METRICS[0]}
        delay=${METRICS[1]}
        qor=${METRICS[2]}
        
        # Write directly to CSV
        echo "$design_name,$sample,\"$recipe\",$area,$delay,$qor" >> "$FINAL_CSV"
        
        # Update top 3 best recipes if better
        for ((j=0; j<3; j++)); do
            if (( qor < best_qors[j] )); then
                # Shift existing entries down
                for ((k=2; k>j; k--)); do
                    best_qors[k]=${best_qors[k-1]}
                    best_areas[k]=${best_areas[k-1]}
                    best_delays[k]=${best_delays[k-1]}
                    best_recipes[k]=${best_recipes[k-1]}
                done
                
                # Insert new entry
                best_qors[j]=$qor
                best_areas[j]=$area
                best_delays[j]=$delay
                best_recipes[j]="$recipe"
                
                echo "New top-$((j+1)) recipe found! Area: $area, Delay: $delay, QoR: $qor"
                break
            fi
        done
    done
    
    # Write top 3 best recipes to file
    echo "Top 3 Best Recipes for $design_name:" >> "$BEST_RECIPES"
    for ((j=0; j<3; j++)); do
        echo "Rank $((j+1)):" >> "$BEST_RECIPES"
        echo "Recipe: ${best_recipes[j]}" >> "$BEST_RECIPES"
        echo "Area: ${best_areas[j]}, Delay: ${best_delays[j]}, QoR: ${best_qors[j]}" >> "$BEST_RECIPES"
        echo "" >> "$BEST_RECIPES"
    done
    echo "----------------------------------------" >> "$BEST_RECIPES"
    
    echo "Completed processing $design_name"
    echo ""
done

echo "Monte Carlo evaluation completed. Results saved to:"
echo "- Consolidated CSV: $FINAL_CSV"
echo "- Best Recipes: $BEST_RECIPES"
