source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup cmake v3_9_0
setup gcc v6_4_0
setup pycurl
setup ifdhc
setup dk2nugenie   v01_06_01f -q debug:e15
setup genie_xsec   v2_12_10   -q DefaultPlusValenciaMEC
setup genie_phyopt v2_12_10   -q dkcharmtau
setup geant4 v4_10_3_p01b -q e15:debug
setup jobsub_client
setup eigen v3_3_5
setup duneanaobj v01_01_01 -q debug:e15:gv1 # Need to be debug not prof
setup hdf5 v1_10_2a -q e15
setup fhiclcpp v4_06_08 -q debug:e15

# edep-sim needs to know where a certain GEANT .cmake file is...
G4_cmake_file=`find ${GEANT4_FQ_DIR}/lib64 -name 'Geant4Config.cmake'`
export Geant4_DIR=`dirname $G4_cmake_file`

# edep-sim needs to have the GEANT bin directory in the path
export PATH=$PATH:$GEANT4_FQ_DIR/bin

# shut up ROOT include errors
export ROOT_INCLUDE_PATH=$ROOT_INCLUDE_PATH:$GENIE_INC/GENIE

# nusystematics paths
#export NUSYST=${PWD}/nusystematics
#export LD_LIBRARY_PATH=${NUSYST}/build/Linux/lib:$LD_LIBRARY_PATH
#export LD_LIBRARY_PATH=${NUSYST}/build/nusystematics/artless:$LD_LIBRARY_PATH
#export FHICL_FILE_PATH=${NUSYST}/nusystematics/fcl:$FHICL_FILE_PATH

# Add pyGeoEff to pythonpath
export PYTHONPATH=${PYTHONPATH}:${PWD}/DUNE_ND_GeoEff/lib/

# duneananobj needs to be in the libs too
export LD_LIBRARY_PATH=${DUNEANAOBJ_LIB}:$LD_LIBRARY_PATH

# finally, add our lib & bin to the paths
mydir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export LD_LIBRARY_PATH=$mydir/lib:$LD_LIBRARY_PATH
export PATH=$mydir/bin:$PATH

# our FCL needs to be findable too
export FHICL_FILE_PATH="$FHICL_FILE_PATH:$mydir/cfg"

# Needed for dumpTree.py to run
export GXMLPATH=${PWD}/sim_inputs:${GXMLPATH}
export GNUMIXML="${PWD}/sim_inputs/GNuMIFlux.xml"
