#!/bin/bash

if [ ! -d ~/.conda/envs/search_env ]; then
    conda env create -n search_env -f /home/docker/proteomics_cluster_submission/env/search_env.yml
fi

cd /home/docker/proteomics_cluster_submission/exes/
if [ ! -f comet.linux.exe ]; then
        wget https://github.com/UWPR/Comet/releases/download/v2024.01.1/comet.linux.exe
    chmod +x comet.linux.exe
fi

if [ ! -f msconvert.sif ]; then
    singularity build --fakeroot msconvert.sif docker://proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:latest
fi

if [ ! -f percolator.sif ]; then
    wget https://github.com/percolator/percolator/releases/download/rel-3-06-05/percolator-noxml-v3-06-linux-amd64.deb
        singularity build --fakeroot percolator.sif percolator.def
fi