params.design = "$launchDir/design.tsv"
params.results_dir = launchDir
design = Channel.of(file(params.design)).splitCsv(header : true, sep : '\t', strip : true)

process params_parser {
    container 'stavisvols/params_parser:latest'
    containerOptions "--bind $launchDir:/data/"

    input:
    val row

    output:
    tuple val(row), path('*.params')

    script:
    """
    python /parser/options_parser.py --params /data/${row.options}
    """
}

process msconvert {
    beforeScript 'mkdir wine_temp'
    afterScript 'rm -rf wine_temp'
    container 'stavisvols/msconvert:latest'
    containerOptions "--bind wine_temp:/wineprefix64 --bind $launchDir:/data/"
    publishDir params.results_dir, mode: 'symlink', pattern: '*.mzML'

    input:
    tuple val(row), path(options)

    output:
    tuple val(row), path(options), path("${row.spectra}.mzML")

    script:
    """
    bash /run_msconvert.sh "--config msconvert.params --outfile ${row.spectra}.mzML /data/${row.spectra}"
    """
}

process comet {
    container 'stavisvols/comet_for_pipeline:latest'
    containerOptions "--bind $launchDir:/data/"

    input:
    tuple val(row), path(options), path(mzml)

    output:
    tuple val(row), path(options), path(mzml), path("${pin}.pin")

    script:
    pin = mzml.getName()
    """
    /comet/comet.linux.exe -Pcomet.params -D/data/$row.sequences -N$pin $mzml
    grep -vE '[[:space:]]-?nan[[:space:]]' ${pin}.pin > tmp
    mv tmp ${pin}.pin
    """
}

process percolator {
    container 'stavisvols/percolator_for_pipeline:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.{psms,peptides}*'

    input:
    tuple val(row), path(options), path(mzml), path(pin)

    output:
    tuple val(row), path(options), path(mzml), path(pin), path("${basename}.psms"), path("${basename}.peptides")
    
    script:
    basename = pin.getName()
    """
    percolator \\
        --parameter-file percolator.params \\
        -m ${basename}.psms \\
        -r ${basename}.peptides \\
        $basename
    """
}

process dinosaur {
    container 'stavisvols/dinosaur_for_pipeline:latest'

    input:
    tuple val(row), path(options), path(mzml), path(pin), path(psms), path(peptides)

    output:
    tuple val(row), path(options), path(mzml), path(pin), path(psms), path(peptides), path("${mzml}.features.tsv")

    script:
    """
    java -Xmx16g -jar /dinosaur/Dinosaur.jar --advParams=dinosaur.params --concurrency=4 --outName=${mzml} $mzml
    """
}

process feature_mapper {
    container 'stavisvols/feature_mapper:latest'
    publishDir params.results_dir, mode: 'copy', pattern: '*.intensities'

    input:
    tuple val(row), path(options), path(mzml), path(pin), path(psms), path(peptides), path(features)

    output:
    tuple val(row), path(options), path(mzml), path(pin), path(psms), path(peptides), path(features), path("${basename_peptides}.intensities")

    script:
    basename_peptides = peptides.getName()
    """
    python /mapper/feature_mapper.py \\
        --features $features \\
        --peptide $peptides \\
        --psms $psms \\
        --mzml $mzml \\
        --params feature_mapper.params \\
        --output ${basename_peptides}.intensities
    """
}

workflow {    
    //parse the combined parameters file
    params_parser(design)

    //identification
    msconvert(params_parser.out)
    comet(msconvert.out)
    percolator(comet.out)
    
    //quantification
    dinosaur(percolator.out)
    feature_mapper(dinosaur.out)
}

