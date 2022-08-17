#!/bin/bash
  
for TRANSLATED_PATH in `find /pnfs/dune/persistent/users/awilkins/cafmaker/translated_signalmask/0m/00/ | tail -n +2`; do
  TRANLSATED_NUM=`echo $TRANSLATED_PATH | sed 's/.*FHC.\(.*\).larnd-sim.tolarsoft_ndtranslated.root/\1/'`
  echo "Checking $TRANLSATED_NUM"

  if grep -Fxq $TRANLSATED_NUM done_nums.txt; then
    echo "$TRANLSATED_NUM already processed"
  else
    echo $TRANSLATED_PATH >> missed_files.txt
  fi
done
