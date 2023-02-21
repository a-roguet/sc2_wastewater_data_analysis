#!/bin/bash


# Help
usage() { printf "Usage: $0 \n[-o <string> Workflow to use (default: 'all'): ""'freyja' (process all demix files in SARS-CoV-2 directory), 'database' (process all files in SARS-CoV-2 directory), 'all' (freyja & database), and 'freyja_run' (process demix files only in the specified SequencingID run)""]\n[-o <string> Output directory in 'Results' (example: ""'2023-01-03'"")]\n[-s <string> (if 'freyja_run' specified) SequencingID (example: ""'Seq078'"")]\n" 1>&2; exit 1; }



# Arguments
while getopts "w:s:o:" o; do
    case "${o}" in
        w)
            workflow=${OPTARG}
            ;;
        s)
            seq_folder=${OPTARG}
            ;;
        o)
            output=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))



# Check the specified directory exists
if [ ! -d /scratch/projects/SARS-CoV-2/Results/$output/ ]; then
            printf "\n'The directory $output does not exist! Please indicate an output directory (-o)\n\n"
            usage
    fi


# Check a workflow is correctly defined
if [ $workflow != "all" ] && [ $workflow != "database" ] && [ $workflow != "freyja" ] && [ $workflow != "freyja_run" ]; then
    printf "\nWorkflow not (properly) defined\n\n"
    usage
fi



# Check that all arguments are correctly defined if 'freyja_run' is selected
if [ $workflow == "freyja_run" ]; then
    if [ -z $seq_folder ]; then
        printf "\n'freyja_run' workflow has been selected, but no SequencingID run (-s) have been defined. Sad :-(\n\n"
        usage
    fi
fi


printf "Parameters used:-w $workflow -o $output -s $seq_folder\n"




#########################################################################################
##### Log
#########################################################################################
printf $(date +%Y%m%d_%H%M%S)"\nParameters used:\n-w $workflow\n-o $output\n-s $seq_folder\n" >> /scratch/projects/SARS-CoV-2/Results/$output/archive/02_DataAnalysis.log
cp "$0" /scratch/projects/SARS-CoV-2/Results/$output/archive/.




#########################################################################################
##### Database (to generate mutation plots)
#########################################################################################


if [ $workflow == "database" ] || [ $workflow == "all" ]; then


    # Update data
    cd /scratch/projects/SARS-CoV-2/

    awk 'BEGIN{OFS="\t"} {print FILENAME,$0}' Seq*/output/*_depth.tsv > ./Results/$output/databases/CallDepthCompiled.tsv
    sed -i 's/\/output\//\t/' ./Results/$output/databases/CallDepthCompiled.tsv
    sed -i 's/_depth.tsv//' ./Results/$output/databases/CallDepthCompiled.tsv

    awk 'BEGIN{OFS="\t"} {print FILENAME,$0}' Seq*/output/*_notfiltered.tsv > ./Results/$output/databases/CallVariantALLCompiled.tsv
    sed -i 's/\/output\//\t/' ./Results/$output/databases/CallVariantALLCompiled.tsv
    sed -i 's/_notfiltered.tsv//' ./Results/$output/databases/CallVariantALLCompiled.tsv


    # Analysis
    cd /scratch/projects/SARS-CoV-2/Results/$output/databases/
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Database_2_*.R


fi






#########################################################################################
##### Freyja 
#########################################################################################


if [ $workflow == "freyja" ] || [ $workflow == "all" ]; then


    cd /scratch/projects/SARS-CoV-2/
    
    # Identify SNPs/barcodes
    for variant in Seq*/output/freyja/*.tsv; do
        depth=${variant/-variant.tsv/-depth}
        out=${variant/-variant.tsv/}; out=${out/\/output\/freyja\//@};
        echo $out
        docker run --rm=True -v $PWD:/data -u $(id -u):$(id -g) staphb/freyja:latest freyja boot $variant $depth --nt 15 --nb 10 --output_base ./Results/$output/freyja/bootstraps/$out --barcodes ./Results/$output/freyja/usher_barcodes_withRecombinantXBBonly.csv
    done


    # Process data for visualization
    cd /scratch/projects/SARS-CoV-2/Results/$output/freyja/

    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_1_*.R
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_2_*.R
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_3_*.R
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_4_*.R
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_5_*.R

fi






#########################################################################################
##### Freyja - if just want to process data for a specific sequencing run
#########################################################################################


if [ $workflow == "freyja_run" ] ; then

    cd /scratch/projects/SARS-CoV-2/

    # Identify SNPs/barcodes
    for variant in $seq_folder/output/freyja/*.tsv; do
        depth=${variant/-variant.tsv/-depth}
        out=${variant/-variant.tsv/}; out=${out/\/output\/freyja\//@};
        echo $out
        docker run --rm=True -v $PWD:/data -u $(id -u):$(id -g) staphb/freyja:latest freyja boot $variant $depth --nt 15 --nb 10 --output_base ./Results/$output/freyja/bootstraps/$out --barcodes ./Results/$output/freyja/usher_barcodes_withRecombinantXBBonly.csv
        #freyja demix $variant $depth --output ./Results/$output/freyja/demix/$out-results.txt
    done


    # Process data for visualization
    cd /scratch/projects/SARS-CoV-2/Results/$output/freyja/

    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_1_*.R
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_2_*.R
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_3_*.R
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_4_*.R
    docker run --rm=True -ti -v $PWD:/data -u $(id -u):$(id -g) r/dashboard:lastest Rscript Freyja_5_*.R


fi

