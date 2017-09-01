#!/bin/bash

set -o errexit
set -o pipefail

OUTPUT_MERGED=$(mktemp -d)/merged.fq.gz
OUTPUT_UNMERGED=$(mktemp -d)/unmerged.fq.gz

TMP_OUT=$(mktemp -d)

INPUT=$1
OUTPUT=$2


clumpify.sh \
	in=${INPUT} \
        out=stdout.fq \
	unpigz=t \
	dedupe \
	optical \
| filterbytile.sh \
	in=stdin.fq \
	out=stdout.fq \
| bbduk.sh \
	in=stdin.fq \
	out=stdout.fq \
	ktrim=r \
	k=23 \
	mink=11 \
	hdist=1 \
	tbo \
	tpe \
	minlen=70 \
	ref=adapters \
	ftm=5 \
	ordered \
| bbduk.sh  \
	in=stdin.fq \
	out=stdout.fq \
	k=31 \
	ref=artifacts,phix \
	ordered \
	cardinality \
| bbmerge.sh \
	in=stdin.fq \
	out=stdout.fq \
	ecco \
	mix \
	vstrict \
	ordered \
| clumpify.sh \
	in=stdin.fq \
	out=stdout.fq \
	ecc \
	passes=4 \
	reorder \
| tadpole.sh \
	in=stdin.fq \
	out=stdout.fq \
	ecc \
	k=62 \
	ordered \
| bbmerge-auto.sh \
	in=stdin.fq \
	out=${OUTPUT_MERGED} \
	outu=stdout.fq \
	strict \
	k=93 \
	extend2=80 \
	rem \
	ordered \
| bbduk.sh  \
	in=stdin.fq \
	out=${OUTPUT_UNMERGED} \
	qtrim=r \
	trimq=10 \
	minlen=70 \
	pigz=t \
	ordered

CMD="spades.py --only-assembler -k25,55,95,125 --phred-offset 33 -o ${TMP_OUT}"

# Check if there are any unmerged reads
if [ -s ${OUTPUT_UNMERGED}  ]
then
	CMD="${CMD} --12 ${OUTPUT_UNMERGED}"
fi

# Check if there are any merged reads
if [ -s ${OUTPUT_MERGED}  ]
then
	CMD="${CMD} -s ${OUTPUT_MERGED}"
fi

eval ${CMD}

cp ${TMP_OUT}/contigs.fasta ${OUTPUT}
rm -f ${OUTPUT_MERGED} ${OUTPUT_UNMERGED} ${TMP_OUT}
