#!/bin/bash
################################################################################
# Jobsub script that processes art-root files with true translated ND depos and
# predicted FD response to the ND depos into an ND CAF with FD predictions
# using paired ND data.
################################################################################

SAM_PROJECT=$1

################################################################################
# Setup general working area

echo "Running on $(hostname) at ${GLIDEIN_Site}. GLIDEIN_DUNESite = ${GLIDEIN_DUNESite}"

OUTDIR=/pnfs/dune/persistent/users/awilkins/cafmaker/cafs/0m/00
EDEPDIR=/pnfs/dune/persistent/users/awilkins/cafmaker/edep/0m/00
GENIEDIR=/pnfs/dune/persistent/users/awilkins/cafmaker/genie/0m/00

LARSOFT_DIRNAME=extrapolation
NDCAFMAKER_DIRNAME=ND_CAFMaker

# This is the top-level dir which is writable
export WORKDIR=${_CONDOR_JOB_IWD}
if [ ! -d "$WORKDIR" ]; then
  export WORKDIR=`echo ~`
fi

cd $WORKDIR

pwd
ls

# Set some useful environment variables for xrootd and IFDH
export IFDH_CP_MAXRETRIES=2
# export IFDH_DEBUG=1
# export IFDH_VERBOSE=1 
export XRD_CONNECTIONRETRY=32
export XRD_REQUESTTIMEOUT=14400
export XRD_REDIRECTLIMIT=255
export XRD_LOADBALANCERTTL=7200
export XRD_STREAMTIMEOUT=14400 # many vary for your job/file type

# Dump the current environment to restore to later
declare -px > env.sh

################################################################################
# Setup working area for larsoft and for data copy in

source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh

cd ${WORKDIR}/${LARSOFT_DIRNAME}

echo localProducts*
source localProducts*/setup-grid
cd srcs
mrbslp

cd $WORKDIR

# Now we have ifdhc, ensure output directory exits
ifdh ls $OUTDIR 0 # recursion depth zero since we don't want listing, only checking existence
if [ $? -ne 0 ]; then
    ifdh mkdir_p $OUTDIR || { echo "Error creating or checking $OUTDIR"; exit 2; }
fi

################################################################################
# Data copy in

echo Finding Project
PROJURL=`ifdh findProject $SAM_PROJECT dune | grep http`
echo PROJURL is $$PROJURL

echo Establishing process
ID=`ifdh establishProcess "$PROJURL" "fdtruedetsim_fdnetworktruereco_makecaf" "$ART_VERSION" "$HOSTNAME" "$USER" "fdtruedetsim_fdnetworktruereco_makecaf.sh" "" "" "" "" || exit 1`
echo ID is $ID

echo Finding file
URI=`ifdh getNextFile $PROJURL $ID || exit`
if [ "x$URI" == "x" ]; then
    echo URI null
    ifdh endProcess $PROJURL $ID
    ifdh cleanup
    exit
fi
echo URI is $URI

echo Fetching file
FNAME=`ifdh fetchInput $URI`
FNAME=`echo "$FNAME" | tail -n1`
if [ "x$FNAME" == "x" ]; then
    echo FNAME is null
    ifdh endProcess $PROJURL $ID
    ifdh cleanup
    exit
fi
echo FNAME is $FNAME

echo Marking as transferred
ifdh updateFileStatus $PROJURL $ID $FNAME transferred
# Not checking the exit status here since I have seen bad exit codes that aren't fatal and I don't
# want to waste good data

################################################################################
# FD true detsim, FD true + network reco + FD reco dumper

FNAMELOCAL=${FNAME##*/}
DETSIM_OUT=${FNAMELOCAL%.root}_fddetsim.root
lar -c detsim_dune10kt_1x2x6_wirecell_refactored_nooptdet_dropSC_fdlabel.fcl -s $FNAME -o $DETSIM_OUT -n 2
if [ $? -ne 0 ]; then
    echo "lar exited with abnormal status $LAR_RESULT. See error outputs."
    exit $?
fi

TRUERECO_OUT=${DETSIM_OUT%.root}_recotrue.root
lar -c reco_dune10kt_1x2x6_truetranslated_inference.fcl -s $DETSIM_OUT -o $TRUERECO_OUT
if [ $? -ne 0 ]; then
    echo "lar exited with abnormal status $LAR_RESULT. See error outputs."
    exit $?
fi

NETWORKRECO_OUT=${TRUERECO_OUT%.root}_reconetwork.root
lar -c reco_dune10kt_1x2x6_networktranslated_inference.fcl -s $TRUERECO_OUT -o $NETWORKRECO_OUT
if [ $? -ne 0 ]; then
    echo "lar exited with abnormal status $LAR_RESULT. See error outputs."
    exit $?
fi

RECODUMP_OUT=${NETWORKRECO_OUT%.root}_recodump.root
lar -c run_RecoDump.sh -s $NETWORKRECO_OUT # output is from TFileService so can't name explicitly
if [ $? -ne 0 ]; then
    echo "lar exited with abnormal status $LAR_RESULT. See error outputs."
    exit $?
fi

pwd
ls

################################################################################
# Get corresponding edep + genie file and make CAF

FILE_NUM=`echo $FNAMELOCAL | sed 's/.*FHC\(.*\).larnd-sim.tolarsoft_ndtranslated.root/\1/'`

EDEP_FILENAME=FHC.${FILE_NUM}.edep_dump.root
ifdh cp ${EDEPDIR}/${EDEP_FILENAME} $EDEP_FILENAME
if [ $? -ne 0 ]; then
    echo "Error during edep-sim copy"
    exit $?
fi
echo "edep edep dump file $EDEP_FILENAME copied"

GENIE_FILENAME=FHC.${FILE_NUM}.ghep.root
ifdh cp ${GENIEDIR}/${GENIE_FILENAME} $GENIE_FILENAME
if [ $? -ne 0 ]; then
    echo "Error during ghep copy"
    exit $?
fi
echo "edep genie file $EDEP_FILENAME copied"

# Want to rollback envoironment to prevent conflict with ND_CAFMaker stuff which is e15.
# Unset all new env vars and then source the old env - probably overkill but it works
unset $(comm -2 -3 <(printenv | sed 's/=.*//' | sort) <(sed -e 's/=.*//' -e 's/declare -x //' env.sh | sort))
source env.sh

# Setup my duneanaobj
export PRODUCTS=$PRODUCTS:${WORKDIR}/ups

cd $NDCAFMAKER_DIRNAME
source ndcaf_setup.sh
cd $WORKDIR

CAF_OUT=FHC.${FILE_NUM}.CAF-fdpreds.root
${NDCAFMAKER_DIRNAME}/bin/makeCAF --dump $EDEP_FILENAME --fdpred $RECODUMP_OUT --ghep $GENIE_FILENAME --out $CAF_OUT

ifdh cp $CAF_OUT ${OUTDIR}/${CAF_OUT}
if [ $? -ne 0 ]; then
    echo "Error during caf copyback"
    exit $?
fi

echo "Marking as consumed"
ifdh updateFileStatus $PROJURL $ID $FNAME consumed 
# Not checking the exit status here since I have seen bad exit codes that aren't fatal and I don't
# want to waste good data

echo "done"

echo "Ending process"
ifdh endProcess $PROJURL $ID

ifdh cleanup

echo "Completed successfully."
exit 0
