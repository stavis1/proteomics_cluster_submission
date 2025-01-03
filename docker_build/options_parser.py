#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-p', '--params', action = 'store', required = True,
                    help = 'The parameters file to parse.')
args = parser.parse_args()

import tomllib 
import tomli_w
with open(args.params, 'rb') as toml:
    options = tomllib.load(toml)

#make toml formatted params files
toml_files = ['download_eggnog_data_params', 
              'emapper_params', 
              'feature_mapper_params',
              'eggnog_quantification_params']
for file in toml_files:
    with open(file, 'wb') as toml:
        tomli_w.dump(options[file], toml)

#percolator
with open('percolator_params', 'w') as percolator:
    for k, v in options['percolator_params'].items():
        if k == 'init-weights':
            flag = '--init-weights'
            val = f'/data/{v}'
        else:
            flag = f'--{k}' if len(k) > 1 else f'-{k}'
            val = v if type(v) != bool else ''
        percolator.write(f'{flag} {val}\n')

#dinosaur
def k_eq_v(opts):
    return '\n'.join(f'{k}={v}' if type(v) != bool else str(k) for k,v in opts.items())

with open('dinosaur_params', 'w') as dinosaur:
    dinosaur.write(k_eq_v(options['dinosaur_params']))

#commet
with open('comet_params', 'w') as comet:
    comet.write(options['comet_params']['header'] + '\n')
    for k,v in options['comet_params'].items():
        if k not in ['COMET_ENZYME_INFO', 'header']:
            comet.write(f'{k} = {v}\n')
    comet.write('[COMET_ENZYME_INFO]\n')
    comet.write(options['comet_params']['COMET_ENZYME_INFO'])
