#=
Top level file for the Simulated Annealing placement routine.
=#

# Structure used for placement.
include("Struct.jl")
# Methods for interacting with that structure
include("Methods.jl")
# Initial Placement Routine
include("InitialPlacement.jl")
# State variable for placement
include("State.jl")
# The actual simulated annealing algorithm
include("Algorithm.jl")
