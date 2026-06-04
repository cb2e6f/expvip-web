# Minimal Test Dataset

This is a minimal dataset for testing the expvip application with:
- 2 genes (GENE001, GENE002)
- 2 tissues (Leaf, Root)
- 2 varieties (TestVar1, TestVar2)
- 2 age stages (seedling, adult plant)
- 2 stress conditions (none, treated)
- 2 experiments with different combinations

## Files Included

1. **test_minimal_factor_order.csv** - Factor ordering configuration
2. **test_minimal_factors.tsv** - Factor definitions (Tissue, Variety, Age, Stress-disease, High level variants)
3. **test_minimal_metadata.tsv** - Experiment metadata (2 experiments)
4. **test_minimal_genes.fasta** - Gene sequences (2 test genes)
5. **test_minimal_exp001_tpm.tsv** - TPM expression data for experiment 1
6. **test_minimal_exp002_tpm.tsv** - TPM expression data for experiment 2
7. **test_minimal_exp001_count.tsv** - Count expression data for experiment 1
8. **test_minimal_exp002_count.tsv** - Count expression data for experiment 2

## How to Use

### Option 1: Use the test init script

Edit your `docker/init.sh` to use the test data instead:

```bash
bash docker/data/test_minimal_init.sh
```

Then restart your Docker containers:

```bash
sudo docker compose down
sudo docker compose up
```

### Option 2: Run individual rake tasks

Inside the Docker container:

```bash
rails db:setup
rails db:migrate
rails load_data:default_factor_order[/data/test_minimal_factor_order.csv]
rails load_data:factor[/data/test_minimal_factors.tsv]
rails load_data:metadata[/data/test_minimal_metadata.tsv]
rails load_data:gff_produced_genes[TestGenome,/data/test_minimal_genes.fasta]
rails load_data:values_mongo[Study001,TestGenome,tpm,/data/test_minimal_exp001_tpm.tsv]
rails load_data:values_mongo[Study001,TestGenome,tpm,/data/test_minimal_exp002_tpm.tsv]
rails load_data:values_mongo[Study001,TestGenome,counts,/data/test_minimal_exp001_count.tsv]
rails load_data:values_mongo[Study001,TestGenome,counts,/data/test_minimal_exp002_count.tsv]
```

## Test Genes to Search

Try searching for:
- `GENE001`
- `GENE002`

## Notes

- All factor names are simple single values (not compound like "none, adult plant, Axis, JI2823")
- This helps isolate whether the issue is with your data structure or with the application code
- You can expand this dataset by adding more factors, experiments, and genes following the same format
