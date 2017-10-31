#=
Root file for the routing related files.
=#
abstract type AbstractRoutingAlgorithm end


# This file converts the top level architecture to a simple graph plus
# translation dictionaries.
include("RoutingGraph.jl")
include("LinkAnnotations.jl")
include("StartStopNodes.jl")
include("RoutingStruct.jl")

# Algorithms
include("Pathfinder.jl")
