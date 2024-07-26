#!/bin/bash
faa=$(sed "${1}q;d" faa_list.txt)
name=$(sed "${1}q;d" basename_list.txt)

conda run -p ~/search_env python clean_fasta.py $faa
./comet.linux.exe -Pmegan_searches.params -Dfiltered_$faa $name.mzML
grep -v -- 'nan' $name.pin > $name.filtered.pin
singularity run percolator.sif percolator -U --reset-algorithm -m $name.pout $name.filtered.pin
conda run -p ~/search_env python percolator_to_flashlfq.py $name.pout
mkdir $name.results
singularity run flashlfq.sif --thr 8 --idt $name.txt --rep ./ --out $name.results
