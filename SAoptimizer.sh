#!/bin/bash

# Define paths
ABC_PATH="./abc"
DESIGNS_DIR="./bobs"
OUTPUT_DIR="./results"
FINAL_CSV="$OUTPUT_DIR/combined_sa_results.csv"
BEST_RECIPES="$OUTPUT_DIR/best_sa_recipes.txt"

# Create output directories
mkdir -p "$OUTPUT_DIR"

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

# Initialize recipe cache
declare -A recipe_cache

# Simulated Annealing parameters
INITIAL_TEMP=100.0
COOLING_RATE=0.98
MIN_TEMP=0.1
MAX_ITERATIONS=500

# Initialize CSV file with header
echo "Design,Iteration,Temperature,Recipe,Area,Delay,QoR,Accepted" > "$FINAL_CSV"

# Initialize best recipes file
> "$BEST_RECIPES"

# Function to evaluate a recipe using ABC
evaluate_recipe() {
    local design=$1
    local recipe=$2
    
    # Check if this recipe has already been evaluated for this design
    local cache_key="${design}:${recipe}"
    if [[ -n "${recipe_cache[$cache_key]}" ]]; then
        # Return cached result
        echo "${recipe_cache[$cache_key]}"
        return
    fi
    
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
    
    # Store result in cache
    result="$area|$delay|$qor"
    recipe_cache[$cache_key]="$result"
    
    echo "$result"
}

# Function to generate a neighbor recipe by modifying current recipe
generate_neighbor() {
    local current_recipe=$1
    
    # Convert recipe string to array
    IFS=' ' read -ra commands <<< "$current_recipe"
    
    # Randomly select a position to modify (excluding first)
    pos=$((1 + RANDOM % (${#commands[@]} - 1)))
    
    # Replace with a random command
    tool_id=$((1 + RANDOM % 8))
    commands[$pos]="${tool_map[$tool_id]}"
    
    # Convert back to string
    neighbor_recipe=""
    for cmd in "${commands[@]}"; do
        neighbor_recipe="$neighbor_recipe$cmd "
    done
    
    echo "$neighbor_recipe"
}

# Process each design
for design in "${DESIGNS[@]}"; do
    design_name=$(basename $design .bench)
    echo "Processing $design_name with Simulated Annealing..."
    
    # Initialize arrays to track top 3 best recipes
    declare -a best_qors=( 999999999 999999999 999999999 )
    declare -a best_areas=( 999999999 999999999 999999999 )
    declare -a best_delays=( 999999999 999999999 999999999 )
    declare -a best_recipes=( "" "" "" )
    
    # Generate initial recipe
    # Randomly choose between balance or strash as first command
    if [ $((RANDOM % 2)) -eq 0 ]; then
        current_recipe="b;" # Start with balance
    else
        current_recipe="st;" # Start with strash
    fi
    
    for ((i=2; i<=20; i++)); do
        tool_id=$((1 + RANDOM % 8))
        current_recipe="$current_recipe ${tool_map[$tool_id]}"
    done
    
    # Evaluate initial recipe
    metrics=$(evaluate_recipe "$design" "$current_recipe")
    IFS='|' read -ra METRICS <<< "$metrics"
    current_area=${METRICS[0]}
    current_delay=${METRICS[1]}
    current_qor=${METRICS[2]}
    
    # Initialize best solution
    best_recipe="$current_recipe"
    best_area=$current_area
    best_delay=$current_delay
    best_qor=$current_qor
    
    # Record initial solution directly to CSV
    echo "$design_name,0,$INITIAL_TEMP,\"$current_recipe\",$current_area,$current_delay,$current_qor,Yes" >> "$FINAL_CSV"
    
    # Start SA process
    temp=$INITIAL_TEMP
    for ((iter=1; iter<=MAX_ITERATIONS; iter++)); do
        echo "Iteration $iter: Temp = $temp"
        
        # Generate neighbor solution
        neighbor_recipe=$(generate_neighbor "$current_recipe")
        
        # Evaluate neighbor
        metrics=$(evaluate_recipe "$design" "$neighbor_recipe")
        IFS='|' read -ra METRICS <<< "$metrics"
        neighbor_area=${METRICS[0]}
        neighbor_delay=${METRICS[1]}
        neighbor_qor=${METRICS[2]}
        
        # Calculate delta (we want to minimize QoR)
        delta=$((neighbor_qor - current_qor))
        
        accepted="No"
        # Decide whether to accept new solution
        if (( delta < 0 )); then
            # Better solution, always accept
            current_recipe="$neighbor_recipe"
            current_area=$neighbor_area
            current_delay=$neighbor_delay
            current_qor=$neighbor_qor
            accepted="Yes"
        else
            # Worse solution, accept with probability based on threshold
            threshold=$(echo "scale=10; $temp * 0.5" | bc -l)
            if (( $(echo "$delta < $threshold" | bc -l) )); then
                current_recipe="$neighbor_recipe"
                current_area=$neighbor_area
                current_delay=$neighbor_delay
                current_qor=$neighbor_qor
                accepted="Yes"
            fi
        fi
        
        # Record current iteration directly to CSV
        echo "$design_name,$iter,$temp,\"$neighbor_recipe\",$neighbor_area,$neighbor_delay,$neighbor_qor,$accepted" >> "$FINAL_CSV"
        
        # Update best solution if needed
        if (( current_qor < best_qor )); then
            best_recipe="$current_recipe"
            best_area=$current_area
            best_delay=$current_delay
            best_qor=$current_qor
            echo "New best solution found! QoR: $best_qor"
        fi
        
        # Update top 3 best recipes if better
        for ((j=0; j<3; j++)); do
            if (( current_qor < best_qors[j] )); then
                # Shift existing entries down
                for ((k=2; k>j; k--)); do
                    best_qors[k]=${best_qors[k-1]}
                    best_areas[k]=${best_areas[k-1]}
                    best_delays[k]=${best_delays[k-1]}
                    best_recipes[k]=${best_recipes[k-1]}
                done
                
                # Insert new entry
                best_qors[j]=$current_qor
                best_areas[j]=$current_area
                best_delays[j]=$current_delay
                best_recipes[j]="$current_recipe"
                
                echo "New top-$((j+1)) recipe found! Area: $current_area, Delay: $current_delay, QoR: $current_qor"
                break
            fi
        done
        
        # Cool down temperature
        temp=$(printf "%.4f" $(echo "$temp * $COOLING_RATE" | bc -l))
        
        # Stop if temperature is too low
        if (( $(echo "$temp < $MIN_TEMP" | bc -l) )); then
            echo "Minimum temperature reached. Stopping."
            break
        fi
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
    
    echo "Best SA recipe for $design_name:"
    echo "$best_recipe"
    echo "Area: $best_area, Delay: $best_delay, QoR: $best_qor"
    echo ""
done

echo "Simulated Annealing optimization completed. Results saved to:"
echo "- Consolidated CSV: $FINAL_CSV"
echo "- Best Recipes: $BEST_RECIPES"
