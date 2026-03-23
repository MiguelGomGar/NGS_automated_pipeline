import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# 1. Load the data
csv_path = "/workspaces/codespaces_NGS/assessments/final_coursework/results/optimization_results.csv"
df = pd.read_csv(csv_path)

# Calculate the percentage of retained reads
total_raw_reads = 1086246
df["reads_pct"] = (df["reads"] / total_raw_reads) * 100

# 2. Pivot the data to create a matrix
reads_pivot = df.pivot(index="q", columns="m", values="reads_pct")
align_pivot = df.pivot(index="q", columns="m", values="alignment_rate")

# 3. Set up the figure
fig, axes = plt.subplots(1, 2, figsize=(14, 6))
fig.suptitle("Cutadapt Parameter Optimization Grid Search", fontsize=16, fontweight='bold')

# --- Retained reads rate plot ---
sns.heatmap(reads_pivot, annot=True, fmt=".1f", cmap="YlOrRd", ax=axes[0], cbar_kws={'label': 'Reads retained (%)'})
axes[0].set_title("Retained Reads Rate")
axes[0].set_xlabel("Minimum Length")
axes[0].set_ylabel("Quality Threshold")

# --- Alignment rate plot ---
sns.heatmap(align_pivot, annot=True, fmt=".2f", cmap="Blues", ax=axes[1], cbar_kws={'label': 'Alignment Rate (%)'})
axes[1].set_title("Alignment Rate")
axes[1].set_xlabel("Minimum Length")
axes[1].set_ylabel("Quality Threshold")

# 4. Adjust the layout and save the image
plt.tight_layout()
plt.savefig("/workspaces/codespaces_NGS/assessments/final_coursework/figures/optimization_heatmaps.png", dpi=300)