#! /usr/bin/env python
"""
Converts ROOT file created by edep-sim into HDF5 format

File from v0.2.3 tag that does not expect the edep-sim units to be converted during the dump.

Swapped fire for argparse and removed tqdm to make it easier to work with edep-sim and ROOT.

Using MakeProject and accessing the data members unique to edep-sim directly (ie. .GetPosition() -> .Position). Trying this because I am struggling to get edep-sim to work in this script in the ND_CAFMaker workflow.
"""

from math import sqrt
import argparse, sys

import numpy as np
import h5py

from ROOT import TFile
import ROOT

# Print the fields in a TG4PrimaryParticle object
def printPrimaryParticle(depth, primaryParticle):
    print(depth,"Class: ", primaryParticle.ClassName())
    print(depth,"Track Id:", primaryParticle.TrackId)
    print(depth,"Name:", primaryParticle.Name)
    print(depth,"PDG Code:",primaryParticle.PDGCode)
    print(depth,"Momentum:",primaryParticle.Momentum.X(),
          primaryParticle.Momentum.Y(),
          primaryParticle.Momentum.Z(),
          primaryParticle.Momentum.E(),
          primaryParticle.Momentum.P(),
          primaryParticle.Momentum.M())

# Print the fields in an TG4PrimaryVertex object
def printPrimaryVertex(depth, primaryVertex):
    print(depth,"Class: ", primaryVertex.ClassName())
    print(depth,"Position:", primaryVertex.Position.X(),
          primaryVertex.Position.Y(),
          primaryVertex.Position.Z(),
          primaryVertex.Position.T())
    print(depth,"Generator:",primaryVertex.GeneratorName)
    print(depth,"Reaction:",primaryVertex.Reaction)
    print(depth,"Filename:",primaryVertex.Filename)
    print(depth,"InteractionNumber:",primaryVertex.InteractionNumber)
    depth = depth + ".."
    for infoVertex in primaryVertex.Informational:
        printPrimaryVertex(depth,infoVertex)
    for primaryParticle in primaryVertex.Particles:
        printPrimaryParticle(depth,primaryParticle)

# Print the fields in a TG4TrajectoryPoint object
def printTrajectoryPoint(depth, trajectoryPoint):
    print(depth,"Class: ", trajectoryPoint.ClassName())
    print(depth,"Position:", trajectoryPoint.Position.X(),
          trajectoryPoint.Position.Y(),
          trajectoryPoint.Position.Z(),
          trajectoryPoint.Position.T())
    print(depth,"Momentum:", trajectoryPoint.Momentum.X(),
          trajectoryPoint.Momentum.Y(),
          trajectoryPoint.Momentum.Z(),
          trajectoryPoint.Momentum.Mag())
    print(depth,"Process",trajectoryPoint.Process)
    print(depth,"Subprocess",trajectoryPoint.Subprocess)

# Print the fields in a TG4Trajectory object
def printTrajectory(depth, trajectory):
    print(depth,"Class: ", trajectory.ClassName())
    depth = depth + ".."
    print(depth,"Track Id/Parent Id:",
          trajectory.TrackId,
          trajectory.ParentId)
    print(depth,"Name:",trajectory.Name)
    print(depth,"PDG Code",trajectory.PDGCode)
    print(depth,"Initial Momentum:",trajectory.InitialMomentum.X(),
          trajectory.InitialMomentum.Y(),
          trajectory.InitialMomentum.Z(),
          trajectory.InitialMomentum.E(),
          trajectory.InitialMomentum.P(),
          trajectory.InitialMomentum.M())
    for trajectoryPoint in trajectory.Points:
        printTrajectoryPoint(depth,trajectoryPoint)

# Print the fields in a TG4HitSegment object
def printHitSegment(depth, hitSegment):
    print(depth,"Class: ", hitSegment.ClassName())
    print(depth,"Primary Id:", hitSegment.PrimaryId)
    print(depth,"Energy Deposit:",hitSegment.EnergyDeposit)
    print(depth,"Secondary Deposit:", hitSegment.SecondaryDeposit)
    print(depth,"Track Length:",hitSegment.TrackLength)
    print(depth,"Start:", hitSegment.Start.X(),
          hitSegment.Start.Y(),
          hitSegment.Start.Z(),
          hitSegment.Start.T())
    print(depth,"Stop:", hitSegment.Stop.X(),
          hitSegment.Stop.Y(),
          hitSegment.Stop.Z(),
          hitSegment.Stop.T())
    print(depth,"Contributor:", [contributor for contributor in hitSegment.Contrib])

# Print the fields in a single element of the SegmentDetectors map.
# The container name is the key, and the hitSegments is the value (a
# vector of TG4HitSegment objects).
def printSegmentContainer(depth, containerName, hitSegments):
    print(depth,"Detector: ", containerName, hitSegments.size())
    depth = depth + ".."
    for hitSegment in hitSegments: printHitSegment(depth, hitSegment)

# Read a file and dump it.
def dump(input_file, output_file):

    # The input file is generated in a previous test (100TestTree.sh).
    inputFile = TFile(input_file)
    inputFile.MakeProject("EDepSimEvents","*","RECREATE++")

    # Get the input tree out of the file.
    inputTree = inputFile.Get("EDepSimEvents")
    print("Class:", inputTree.ClassName())

    # Attach a brach to the events.
    event = ROOT.TG4Event()
    inputTree.SetBranchAddress("Event",ROOT.AddressOf(event))

    # Read all of the events.
    entries = inputTree.GetEntriesFast()

    segments_dtype = np.dtype([("eventID", "u4"), ("z_end", "f4"),
                               ("trackID", "u4"), ("tran_diff", "f4"),
                               ("z_start", "f4"), ("x_end", "f4"),
                               ("y_end", "f4"), ("n_electrons", "u4"),
                               ("pdgId", "i4"), ("x_start", "f4"),
                               ("y_start", "f4"), ("t_start", "f4"),
                               ("dx", "f4"), ("long_diff", "f4"),
                               ("pixel_plane", "i4"), ("t_end", "f4"),
                               ("dEdx", "f4"), ("dE", "f4"), ("t", "f4"),
                               ("y", "f4"), ("x", "f4"), ("z", "f4"),
                               ("n_photons","f4")])

    trajectories_dtype = np.dtype([("eventID", "u4"), ("trackID", "u4"),
                                   ("parentID", "i4"),
                                   ("pxyz_start", "f4", (3,)),
                                   ("xyz_start", "f4", (3,)), ("t_start", "f4"),
                                   ("pxyz_end", "f4", (3,)),
                                   ("xyz_end", "f4", (3,)), ("t_end", "f4"),
                                   ("pdgId", "i4"), ("start_process", "u4"),
                                   ("start_subprocess", "u4"),
                                   ("end_process", "u4"),
                                   ("end_subprocess", "u4")])

    vertices_dtype = np.dtype([("eventID","u4"),("x_vert","f4"),("y_vert","f4"),("z_vert","f4")])

    segments_list = []
    trajectories_list = []
    vertices_list = []

    for jentry in range(entries):
        sys.stdout.write("\r%d" % jentry)
        sys.stdout.flush()
        nb = inputTree.GetEntry(jentry)
        if nb <= 0:
            continue

        print("Class: ", event.ClassName())
        print("Event number:", event.EventId)

        # Dump the primary vertices
        vertex = np.empty(len(event.Primaries), dtype=vertices_dtype)
        for primaryVertex in event.Primaries:
            #printPrimaryVertex("PP", primaryVertex)
            vertex["eventID"] = event.EventId
            vertex["x_vert"] = primaryVertex.Position.X()
            vertex["y_vert"] = primaryVertex.Position.Y()
            vertex["z_vert"] = primaryVertex.Position.Z()
            vertices_list.append(vertex)

        # Dump the trajectories
        print("Number of trajectories ", len(event.Trajectories))
        trajectories = np.empty(len(event.Trajectories), dtype=trajectories_dtype)
        for iTraj, trajectory in enumerate(event.Trajectories):
            start_pt, end_pt = trajectory.Points[0], trajectory.Points[-1]
            trajectories[iTraj]["eventID"] = event.EventId
            trajectories[iTraj]["trackID"] = trajectory.TrackId
            trajectories[iTraj]["parentID"] = trajectory.ParentId
            trajectories[iTraj]["pxyz_start"] = (start_pt.Momentum.X(), start_pt.Momentum.Y(), start_pt.Momentum.Z())
            trajectories[iTraj]["pxyz_end"] = (end_pt.Momentum.X(), end_pt.Momentum.Y(), end_pt.Momentum.Z())
            trajectories[iTraj]["xyz_start"] = (start_pt.Position.X(), start_pt.Position.Y(), start_pt.Position.Z())
            trajectories[iTraj]["xyz_end"] = (end_pt.Position.X(), end_pt.Position.Y(), end_pt.Position.Z())
            trajectories[iTraj]["t_start"] = start_pt.Position.T()
            trajectories[iTraj]["t_end"] = end_pt.Position.T()
            trajectories[iTraj]["start_process"] = start_pt.Process
            trajectories[iTraj]["start_subprocess"] = start_pt.Subprocess
            trajectories[iTraj]["end_process"] = end_pt.Process
            trajectories[iTraj]["end_subprocess"] = end_pt.Subprocess
            trajectories[iTraj]["pdgId"] = trajectory.PDGCode

        trajectories_list.append(trajectories)

        # Dump the segment containers
        print("Number of segment containers:", event.SegmentDetectors.size())

        for containerName, hitSegments in event.SegmentDetectors:

            segment = np.empty(len(hitSegments), dtype=segments_dtype)
            for iHit, hitSegment in enumerate(hitSegments):
                segment[iHit]["eventID"] = event.EventId
                segment[iHit]["trackID"] = trajectories[hitSegment.Contrib[0]]["trackID"]
                segment[iHit]["x_start"] = hitSegment.Start.X() / 10
                segment[iHit]["y_start"] = hitSegment.Start.Y() / 10
                segment[iHit]["z_start"] = hitSegment.Start.Z() / 10
                segment[iHit]["x_end"] = hitSegment.Stop.X() / 10
                segment[iHit]["y_end"] = hitSegment.Stop.Y() / 10
                segment[iHit]["z_end"] = hitSegment.Stop.Z() / 10
                segment[iHit]["dE"] = hitSegment.EnergyDeposit
                segment[iHit]["t"] = 0
                segment[iHit]["t_start"] = 0
                segment[iHit]["t_end"] = 0
                xd = segment[iHit]["x_end"] - segment[iHit]["x_start"]
                yd = segment[iHit]["y_end"] - segment[iHit]["y_start"]
                zd = segment[iHit]["z_end"] - segment[iHit]["z_start"]
                dx = sqrt(xd**2 + yd**2 + zd**2)
                segment[iHit]["dx"] = dx
                segment[iHit]["x"] = (segment[iHit]["x_start"] + segment[iHit]["x_end"]) / 2.
                segment[iHit]["y"] = (segment[iHit]["y_start"] + segment[iHit]["y_end"]) / 2.
                segment[iHit]["z"] = (segment[iHit]["z_start"] + segment[iHit]["z_end"]) / 2.
                segment[iHit]["dEdx"] = hitSegment.EnergyDeposit / dx if dx > 0 else 0
                segment[iHit]["pdgId"] = trajectories[hitSegment.Contrib[0]]["pdgId"]
                segment[iHit]["n_electrons"] = 0
                segment[iHit]["long_diff"] = 0
                segment[iHit]["tran_diff"] = 0
                segment[iHit]["pixel_plane"] = 0
                segment[iHit]["n_photons"] = 0

            segments_list.append(segment)

    trajectories_list = np.concatenate(trajectories_list, axis=0)
    segments_list = np.concatenate(segments_list, axis=0)
    vertices_list = np.concatenate(vertices_list, axis=0)

    with h5py.File(output_file, "w") as f:
        f.create_dataset("trajectories", data=trajectories_list)
        f.create_dataset("segments", data=segments_list)
        f.create_dataset("vertices", data=vertices_list)

def parse_arguments():
    parser = argparse.ArgumentParser()

    parser.add_argument("input_file")
    parser.add_argument("output_file")

    args = parser.parse_args()

    return (args.input_file, args.output_file)

if __name__ == "__main__":
    arguments = parse_arguments()

    dump(*arguments)
