#!/bin/bash -e
sudo docker compose exec -T expvip bash <<'EOF'
set -e
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
EOF