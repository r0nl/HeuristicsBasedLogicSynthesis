import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import ScalarFormatter

# Create a folder for graphs
graph_folder = './graph'
if not os.path.exists(graph_folder):
    os.makedirs(graph_folder)

# Read the CSV files
mc_df = pd.read_csv('./results/combined_mc_results.csv')
sa_df = pd.read_csv('./results/combined_sa_results.csv')

# List of designs to process
designs = ['simple_spi_orig', 'pci_orig', 'aes_secworks_orig']
# Metrics to plot
metrics = ['Area', 'Delay', 'QoR']

# Define colors for consistent visualization across approaches
colors = {'MC': 'red', 'SA': 'green'}

# Process each design
for design in designs:
    # Process each metric
    for metric in metrics:
        # Create a new figure for each metric
        plt.figure(figsize=(10, 6))
        
        # Extract design name without extension for MC data
        mc_design_name = design
        # Get MC data for this design
        design_mc = mc_df[mc_df['Design'] == mc_design_name]
        design_mc = design_mc.sort_values('Sample')
        
        # Get SA data for this design
        sa_design_name = design
        design_sa = sa_df[sa_df['Design'] == sa_design_name]
        design_sa = design_sa.sort_values('Iteration')
        
        # Plot Monte Carlo results
        plt.plot(design_mc['Sample'], design_mc[metric], 
                 color=colors['MC'], linestyle='-', 
                 label=f'Monte Carlo {metric}')
        
        # Find and mark the best MC point
        if metric == 'QoR':
            best_idx = design_mc[metric].idxmin()
        else:
            best_idx = design_mc[metric].idxmin()  # For Area and Delay, smaller is better
            
        best_sample = design_mc.loc[best_idx, 'Sample']
        best_value = design_mc.loc[best_idx, metric]
        plt.scatter(best_sample, best_value, s=150, color=colors['MC'], 
                   marker='*', zorder=5, 
                   label=f'Best MC {metric}: {best_value:.2f}')
        
        # Plot SA results
        if not design_sa.empty:
            if metric == 'Area':
                sa_column = 'Area'
            elif metric == 'Delay':
                sa_column = 'Delay'
            else:  # QoR
                sa_column = 'QoR'
                
            plt.plot(design_sa['Iteration'], design_sa[sa_column],
                     color=colors['SA'], linestyle='-',
                     label=f'Simulated Annealing {metric}')
            
            # Find and mark the best SA point
            best_sa_idx = design_sa[sa_column].idxmin()
            best_sa_sample = design_sa.loc[best_sa_idx, 'Iteration']
            best_sa_value = design_sa.loc[best_sa_idx, sa_column]
            plt.scatter(best_sa_sample, best_sa_value, s=150, color=colors['SA'],
                        marker='*', zorder=5,
                        label=f'Best SA {metric}: {best_sa_value:.2f}')
        
        # Add grid lines, labels, and title
        plt.grid(True, alpha=0.3)
        plt.xlabel('Sample Number', fontsize=12)
        plt.ylabel(f'{metric} Value', fontsize=12)
        plt.title(f'{design} - {metric} Comparison: Monte Carlo vs Simulated Annealing', fontsize=14)
        
        # Format y-axis labels to avoid scientific notation
        plt.gca().yaxis.set_major_formatter(ScalarFormatter(useOffset=False))
        
        # Add legend
        plt.legend(loc='best', fontsize=10)
        
        # Adjust layout
        plt.tight_layout()
        
        # Save the individual graph in the graph folder
        plt.savefig(os.path.join(graph_folder, f'{design}_{metric}_comparison.png'), dpi=300, bbox_inches='tight')
        
        # Close the figure to free memory
        plt.close()

print("All comparison graphs generated successfully!")
