SAM_PROJECT=$1

jobsub_submit -G dune \
              -N 699 \
              --memory=4000MB \
              --disk=150GB \
              --expected-lifetime=48h \
              --resource-provides=usage_model=DEDICATED,OPPORTUNISTIC,OFFSITE \
              --tar_file_name=dropbox:///dune/app/users/awilkins/nd_cafs/fdreco_makeCAF_job.tar.gz \
              --use-cvmfs-dropbox -l '+SingularityImage=\"/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-wn-sl7:latest\"' \
              --append_condor_requirements='(TARGET.HAS_Singularity==true&&TARGET.HAS_CVMFS_dune_opensciencegrid_org==true&&TARGET.HAS_CVMFS_larsoft_opensciencegrid_org==true&&TARGET.CVMFS_dune_opensciencegrid_org_REVISION>=1105&&TARGET.HAS_CVMFS_fifeuser1_opensciencegrid_org==true&&TARGET.HAS_CVMFS_fifeuser2_opensciencegrid_org==true&&TARGET.HAS_CVMFS_fifeuser3_opensciencegrid_org==true&&TARGET.HAS_CVMFS_fifeuser4_opensciencegrid_org==true)' \
              --blacklist US_BNL \
              file:///dune/app/users/awilkins/nd_cafs/fdtruedetsim_fdnetworktruereco_makecaf_job.sh $SAM_PROJECT
