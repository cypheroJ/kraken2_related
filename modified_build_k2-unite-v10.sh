#!/bin/bash

set -u  # Protect against uninitialized vars.
set -e  # Stop on error
set -o pipefail  # Stop on failures in non-final pipeline commands

if [[ $# -ne 3 ]]
then
    echo "usage: $(basename "$0") database unite-fasta threads"
	echo ""
	echo "where:	database:	The local folder in which the database will be created"
	echo "	unite-fasta:	A unite FASTA file"
	echo "	threads:	The number of threads to use during db creation"
	exit 1
fi

if [[ ! -e "$2" ]]
then
	echo "'$2' No such file"
	exit 2
fi

if [[ -e "$1" ]]
then
	echo "Database folder '$1' already exists"
	exit 3
fi

KRAKEN2_DB_NAME=$1
FASTA_PATH="$(dirname $(readlink -f "$2"))"
FASTA_FILE="$(basename "$2")"
KRAKEN2_THREAD_CT=$3

mkdir -p "$KRAKEN2_DB_NAME"
pushd "$KRAKEN2_DB_NAME"
mkdir -p data taxonomy library
pushd data
cp ${FASTA_PATH}/"${FASTA_FILE}" .

# we will try to convert the unite fasta into a GG style format
# to use that part of the k2 pipeline to create the database.

# create a taxonomy mapping file
sudo sed -E 's/>[^;]+\|([^\|]+)\|*.*/>\1/g' ${FASTA_PATH}/${FASTA_FILE} | grep -F ">" | awk '{print NR"\t"$0}' > ${FASTA_FILE}".tsv"

# insert whitespace after ;
sudo sed -i 's/;\s*/; /g' ${FASTA_FILE}".tsv"

# replace sequence name with the seqid (taxon?)
sudo awk '{if ($0 ~ />/) {print ">"++count} else {print $0}}' ${FASTA_PATH}/"${FASTA_FILE}" > "${FASTA_FILE}"

~/localdatabase/build_gg_taxonomy.pl ${FASTA_FILE}".tsv"

popd
mv data/names.dmp data/nodes.dmp taxonomy/
mv data/seqid2taxid.map .
mv data/${FASTA_FILE} library/unite.fna
popd

kraken2-build --db "$KRAKEN2_DB_NAME" --build --threads "$KRAKEN2_THREAD_CT"
