#!/bin/bash

# Define paths
INITIAL_STATS="./results/initial_stats.txt"
RECIPES_DIR="./recipes"
RESULTS_DIR="./results"
FINAL_CSV="./results/final_combined.csv"

# Create header for final CSV
echo "Design,Initial_Area,Initial_Delay,Initial_QoR,Recipe,Tool1,Tool2,Tool3,Tool4,Tool5,Tool6,Tool7,Tool8,Tool9,Tool10,Tool11,Tool12,Tool13,Tool14,Tool15,Tool16,Tool17,Tool18,Tool19,Tool20,Final_Area,Final_Delay,Final_QoR" > "$FINAL_CSV"

# Check if initial stats file exists
if [ ! -f "$INITIAL_STATS" ]; then
    echo "Error: Initial stats file $INITIAL_STATS not found!"
    exit 1
fi

# Command mapping dictionary - updated to match s2.sh tool_map
declare -A command_map=(
    ["b;"]=1
    ["rw;"]=2
    ["rf;"]=3
    ["rs;"]=4
    ["st;"]=5
    ["rwz;"]=6
    ["f;"]=7
    ["rfz;"]=8
)

# Process each design
while IFS=',' read -r design initial_area initial_delay initial_qor; do
    # Skip header line
    if [[ "$design" == "Design" ]]; then
        continue
    fi
    
    # Extract design name without extension for file naming consistency
    design_name="${design}"
    
    recipe_file="$RECIPES_DIR/${design_name}_recipes.txt"
    metrics_file="$RESULTS_DIR/${design}_metrics.txt"
    
    # Check if files exist
    if [ ! -f "$recipe_file" ]; then
        echo "Warning: Recipe file $recipe_file not found, skipping..."
        continue
    fi
    if [ ! -f "$metrics_file" ]; then
        echo "Warning: Metrics file $metrics_file not found, skipping..."
        continue
    fi
    
    # Read recipes and metrics line by line
    recipe_num=1
    while IFS= read -r recipe; do
        # Get metrics line by recipe number
        metrics=$(grep "^$design,$recipe_num," "$metrics_file")
        
        if [ -z "$metrics" ]; then
            echo "Warning: No metrics found for $design recipe $recipe_num"
            ((recipe_num++))
            continue
        fi
        
        # Split metrics into components
        IFS=',' read -r _ _ final_area final_delay final_qor <<< "$metrics"
        
        # Convert abbreviated commands to full names
        full_recipe=""
        tool_columns=""
        tool_count=0
        for cmd in $recipe; do
            full_cmd="${command_map[$cmd]}"
            if [ -z "$full_cmd" ]; then
                full_cmd="unknown_command;"
            fi
            full_recipe="$full_recipe$cmd"
            tool_columns="$tool_columns,$full_cmd"
            ((tool_count++))
        done
        full_recipe="${full_recipe%;}" # Remove trailing semicolon

        # Pad remaining tool columns with 0 if less than 20 tools
        while [ $tool_count -lt 20 ]; do
            tool_columns="$tool_columns,0"
            ((tool_count++))
        done

        
        # Write to CSV
        echo "$design,$initial_area,$initial_delay,$initial_qor,\"$full_recipe\"$tool_columns,$final_area,$final_delay,$final_qor" >> "$FINAL_CSV"
        
        ((recipe_num++))
    done < "$recipe_file"
    
done < "$INITIAL_STATS"

echo "Final CSV created at $FINAL_CSV"
