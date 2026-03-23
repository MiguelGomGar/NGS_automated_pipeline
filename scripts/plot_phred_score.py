import numpy as np
import matplotlib.pyplot as plt

# 1. Generate Phred score values (from 0 to 40, the most common range)
phred_scores = np.arange(10, 25)

# 2. Calculate the error probability using the formula: P = 10^(-Q/10)
error_probabilities = 10 ** (-phred_scores / 10.0)

# 3. Set up the figure and the plot
plt.figure(figsize=(8, 6))
plt.plot(phred_scores, error_probabilities, marker='o', linestyle='-', color='tab:blue')

# 4. Add title and labels
plt.title('Error Probability vs. Phred Score', fontsize=14, fontweight='bold')
plt.xlabel('Phred Quality Score (Q)', fontsize=12)
plt.ylabel('Probability of Incorrect Base Call (P)', fontsize=12)

# Use a logarithmic scale on the Y-axis to better visualize the exponential drop
#plt.yscale('log')
plt.grid(True, which="both", ls="--", alpha=0.7)

# # 5. Annotate key values (typical quality thresholds)
# thresholds = [10, 20, 30, 40]
# for q in thresholds:
#     p = 10 ** (-q / 10.0)
#     # Place an arrow and text pointing to the exact probability
#     plt.annotate(f'Q={q} (P={p:.4f})', xy=(q, p), xytext=(q + 1, p * 1.5),
#                 arrowprops=dict(arrowstyle="->", color='black'))

# 6. Adjust layout and save the image
plt.tight_layout()
plt.savefig('/workspaces/codespaces_NGS/assessments/final_coursework/figures/phred_probability.png')