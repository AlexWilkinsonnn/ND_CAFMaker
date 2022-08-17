#!/bin/bash

OUT_DIR=/pnfs/dune/persistent/users/awilkins/cafmaker/old_cafs/0m/00
DONE_FILE=done.txt

source ../ndcaf_setup.sh
export LD_LIBRARY_PATH=/dune/app/users/awilkins/nd_cafs/ND_CAFMaker:$LD_LIBRARY_PATH

for FDRECO_FILE in `ifdh ls /pnfs/dune/persistent/users/awilkins/cafmaker/fdreco/0m/00/ | tail -n +2`; do
  echo $FDRECO_FILE
  FILE_NUM=`echo $FDRECO_FILE | \
            sed 's/.*FHC.\(.*\).larnd-sim.tolarsoft_ndtranslated_fddetsim_recotrue_reconetwork_recodump.root/\1/'`

  if grep -Fxq $FILE_NUM $DONE_FILE; then
    echo "$FILE_NUM already processed"
  else
    echo "Processing $FILE_NUM"

    EDEPDUMP_FILE=/pnfs/dune/persistent/users/awilkins/cafmaker/edep/0m/00/FHC.${FILE_NUM}.edep_dump.root
    GENIE_FILE=/pnfs/dune/persistent/users/awilkins/cafmaker/genie/0m/00/FHC.${FILE_NUM}.ghep.root
    OUT_FILE=FHC.${FILE_NUM}.oldCAF-fdpreds.root

    ifdh cp -D $FDRECO_FILE .
    ifdh cp -D $EDEPDUMP_FILE .
    ifdh cp -D $GENIE_FILE .

    ../makeCAF --infile $EDEPDUMP_FILE \
               --gfile $GENIE_FILE \
               --outfile $OUT_FILE \
               --fhicl ../sim_inputs/fhicl.fcl \
               --fdpreds $FDRECO_FILE

    ifdh cp -D $OUT_FILE $OUT_DIR
    rm ${EDEPDUMP_FILE##*/}
    rm ${GENIE_FILE##*/}
    rm ${FDRECO_FILE##*/}
    rm ${OUT_FILE}

    echo $FILE_NUM >> $DONE_FILE
  fi
done
