#!/usr/bin/env python
# coding: utf-8

# # 10x Visium (working from DLPFC tutorial)

# This is the analysis pipeline for the Visium test  
# Modified by: Ryan  
# Date: 250617

# ## Preparation

# In[1]:


import warnings
warnings.filterwarnings("ignore")
import pandas as pd, numpy as np, scanpy as sc, matplotlib.pyplot as plt, os, sys
os.environ["OMP_NUM_THREADS"] = "4"
os.environ["OPENBLAS_NUM_THREADS"] = "4"
os.environ["MKL_NUM_THREADS"] = "4"
os.environ["VECLIB_MAXIMUM_THREADS"] = "4"
os.environ["NUMEXPR_NUM_THREADS"] = "4"
try:
    from importlib import metadata  # Python 3.8+
except ImportError:
    import importlib_metadata as metadata
from sklearn.metrics.cluster import adjusted_rand_score
import STAGATE


import argparse

def get_args():
    parser = argparse.ArgumentParser(description="Run STAGATE on a sample")
    parser.add_argument("--sample_name", type=str, required=True, help="Sample name")
    parser.add_argument("--input_dir", type=str, required=True, help="Input directory (cellranger outs directory)")
    parser.add_argument("--output_dir", type=str, required=True, help="Output directory (STAGATE output directory)")
    return parser.parse_args()

def read_data(input_dir):
    adata = sc.read_visium(path=input_dir, count_file='filtered_feature_bc_matrix.h5')
    return adata

def find_duplicates_with_set(input_list):
    seen = set()
    duplicates = set()
    for item in input_list:
        if item in seen:
            duplicates.add(item)
        else:
            seen.add(item)
    return list(duplicates)

def normalize_data(adata):
    print(f"Normalizing data...")
    sc.pp.highly_variable_genes(adata, flavor="seurat_v3", n_top_genes=3000)  
    sc.pp.normalize_total(adata, target_sum=1e4)
    sc.pp.log1p(adata)
    print(f"Data normalized.")
    return adata

# spatial coordinates for first 5 barcodes
def construct_spatial_network(adata):
    print(adata.obsm['spatial'][:5])
    STAGATE.Cal_Spatial_Net(adata, rad_cutoff=450)
    STAGATE.Stats_Spatial_Net(adata)
    fig = plt.gcf() # Get current figure
    fig.savefig(os.path.join(args.output_dir, f'{args.sample_name}_spatial_network_stats.png'), dpi=300, bbox_inches='tight')
    return adata

args = get_args()
adata = read_data(args.input_dir)

duplicates = find_duplicates_with_set(list(adata.var_names))
print(f"Found {len(duplicates)} duplicate gene names: {duplicates}. making var_names unique...")
adata.var_names_make_unique()
adata = normalize_data(adata)
adata = construct_spatial_network(adata)

adata = STAGATE.train_STAGATE(adata, alpha=0)

# calculate nearest neighbors distance matrix and a neighborhood graph of observations
sc.pp.neighbors(adata, use_rep='STAGATE')


# embed the neighborhood graph using UMAP
sc.tl.umap(adata)
# plot UMAP
sc.pl.umap(adata)
fig = plt.gcf()
fig.savefig(os.path.join(args.output_dir, f'{args.sample_name}_plain_umap.png'), dpi=300, bbox_inches='tight')

adata_post_umap = adata
# cluster the data using mclust
adata = STAGATE.mclust_R(adata, used_obsm='STAGATE', num_cluster=13)


img = adata.uns['spatial'][args.sample_name]['images']['hires']
coords = np.array(adata.obsm['spatial'], dtype=float)
clusters = adata.obs['mclust'].astype('category')
scalefactor = adata.uns['spatial'][args.sample_name]['scalefactors']['tissue_hires_scalef']

scaled_coords = coords * scalefactor

fig, axs = plt.subplots(1, 2, figsize=(16, 8))

# Left: histology + transparent cluster dots (unflipped coords)
axs[0].imshow(img)
axs[0].scatter(
    scaled_coords[:, 0], scaled_coords[:, 1],
    c=clusters.cat.codes,
    cmap='tab20',
    s=20,
    edgecolors='none',
    alpha=0.8
)
axs[0].set_title('Histology + Clusters (Unflipped)')
axs[0].axis('off')

# Right: pure histology (no clusters)
axs[1].imshow(img)
axs[1].set_title('Histology Only')
axs[1].axis('off')

plt.tight_layout()
#plt.show()
fig = plt.gcf()
fig.savefig(os.path.join(args.output_dir, f'{args.sample_name}_clustered_histology.png'), dpi=300, bbox_inches='tight')


# In[40]:


sc.pl.umap(adata, color = "mclust", title='mclust UMAP')
fig = plt.gcf()
fig.savefig(os.path.join(args.output_dir, f'{args.sample_name}_mclust_umap.png'), dpi=300, bbox_inches='tight')

# In[41]:




# In[42]:


cluster_col = 'mclust'


# In[43]:


sc.tl.rank_genes_groups(adata, groupby=cluster_col, method='wilcoxon')


# In[44]:


print(type(adata.uns['rank_genes_groups']['names']))
print(adata.uns['rank_genes_groups']['names'])
print(adata.uns['rank_genes_groups']['names'].shape if hasattr(adata.uns['rank_genes_groups']['names'], 'shape') else 'No shape')


# In[45]:


names = adata.uns['rank_genes_groups']['names']  # recarray of tuples (shape: n_genes,)

n_top = 5
n_clusters = len(names[0])  # number of clusters (tuple length)

top_genes_per_cluster = {}

for c in range(n_clusters):
    # Extract gene c from each tuple for the top n_top ranks
    top_genes = [names[i][c] for i in range(n_top)]
    top_genes_per_cluster[c] = top_genes

# Print top genes for each cluster index
for cluster_idx, genes in top_genes_per_cluster.items():
    print(f"Cluster {cluster_idx}: {genes}")


"""
Cluster 0: ['COL1A1', 'COL3A1', 'COL1A2', 'LUM', 'LYZ']
Cluster 1: ['CCDC80', 'DCN', 'C1R', 'IGFBP4', 'PI16']
Cluster 2: ['MGP', 'FDCSP', 'IGKC', 'IGHG1', 'TMSB10']
Cluster 3: ['FABP4', 'SCD', 'ADIPOQ', 'PLIN1', 'CD36']
Cluster 4: ['CHIT1', 'MMP9', 'APOE', 'SPP1', 'GPNMB']
Cluster 5: ['SYT8', 'MSLN', 'COL9A3', 'S100A16', 'MIA']
Cluster 6: ['PPP1R14C', 'SEPTIN3', 'ITGB6', 'SLC7A5', 'TUBB2B']
Cluster 7: ['VSTM2L', 'CDH1', 'VWA2', 'LSR', 'TM7SF3']
Cluster 8: ['KRT14', 'APOD', 'CNN1', 'IGHA1', 'MYLK']
Cluster 9: ['FBXO32', 'CALML5', 'MMP7', 'SFRP1', 'MUC1']
Cluster 10: ['FABP7', 'SCG5', 'AARD', 'CRYBG1', 'KRT15']
Cluster 11: ['CNTN1', 'TNFSF13B', 'TP53BP2', 'TTYH1', 'EXOC6B']
Cluster 12: ['SELL', 'TRAC', 'IL7R', 'CXCR4', 'TRBC2']
"""

adata.write_h5ad(os.path.join(args.output_dir, f'{args.sample_name}_STAGATE_output.h5ad'))

