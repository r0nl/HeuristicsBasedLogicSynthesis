#!/bin/bash

# Define paths
ABC_PATH="./abc"
DESIGNS_DIR="./bobs"
OUTPUT_DIR="./sa_results"
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

# Initialize recipe cache
declare -A recipe_cache

# Simulated Annealing parameters
INITIAL_TEMP=100.0
COOLING_RATE=0.98
MIN_TEMP=0.1
MAX_ITERATIONS=500

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

    area_int=${area%.*}
    delay_int=${delay%.*}
    qor=$((area_int * delay_int))
    
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
    
    # Create metrics output file
    metrics_file="$METRICS_DIR/${design_name}_sa_metrics.txt"
    echo "Iteration,Temperature,Recipe,Area,Delay,QoR,Accepted" > "$metrics_file"
    
    # Record initial solution
    echo "0,$INITIAL_TEMP,\"$current_recipe\",$current_area,$current_delay,$current_qor,Yes" >> "$metrics_file"
    
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
            # Worse solution, accept with probability
            # exp(-delta/temp)
            threshold=$(echo "scale=10; $temp * 0.5" | bc -l)
            if (( $(echo "$delta < $threshold" | bc -l) )); then
                current_recipe="$neighbor_recipe"
                current_area=$neighbor_area
                current_delay=$neighbor_delay
                current_qor=$neighbor_qor
                accepted="Yes"
            fi
        fi
        
        # Record current iteration
        echo "$iter,$temp,\"$neighbor_recipe\",$neighbor_area,$neighbor_delay,$neighbor_qor,$accepted" >> "$metrics_file"
        
        # Update best solution if needed
        if (( current_qor < best_qor )); then
            best_recipe="$current_recipe"
            best_area=$current_area
            best_delay=$current_delay
            best_qor=$current_qor
            echo "New best solution found! QoR: $best_qor"
        fi
        
        # Cool down temperature
        temp=$(printf "%.4f" $(echo "$temp * $COOLING_RATE" | bc -l))
        
        # Stop if temperature is too low
        if (( $(echo "$temp < $MIN_TEMP" | bc -l) )); then
            echo "Minimum temperature reached. Stopping."
            break
        fi
    done
    
    # Save the best recipe found
    echo "$best_recipe" > "$RECIPES_DIR/${design_name}_sa_best_recipe.txt"
    
    echo "Best SA recipe for $design_name:"
    echo "$best_recipe"
    echo "Area: $best_area, Delay: $best_delay, QoR: $best_qor"
    echo ""
done

echo "Simulated Annealing optimization completed. Results saved to $OUTPUT_DIR directory."
