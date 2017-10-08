#=
Framework for the Kilocore project using the rest of the Mapper infrastructure.

Special methods for:

Architecture Creation
Taskgraph Construction
Placement Related Functions
Routing Related Functions

will be defined in this folder.
=#

################################################################################
# Attributes to determine what tasks may be mapped to which components in
# the architecture.
################################################################################

#=
Model for asap4
=#
const _kilocore_attributes = Set([
      "processor",
      "memory_processor",
      "fast_processor",
      "viterbi",
      "fft",
      "input_handler",
      "output_handler",
      "memory_1port",
      "memory_2port",
     ])

################################################################################
# Custrom Architecture used by this Framework
################################################################################

#=
Custom Abstract Architectures defined in this framework. 
Both KiloCore and Asap4 will wall in the KCArchitecture type.
Principles of the type include:

- attributes for components that determine mapping.
=#
abstract type AbstractKC <: AbstractArchitecture end
struct KCArchitecture <: AbstractKC end
include("asap4.jl")

# REQUIRED METHODS
"""
    ismappable(::AbstractKC, c::Component)

The default criteria for a component being a mappable component is that is must
have an "attributes" field in its metadata (value should be a vector of strings)
and the length of that vector should be greater than 0.
"""
function ismappable(::AbstractKC, c::Component)
    return haskey(c.metadata, "attributes") && length(c.metadata["attributes"]) > 0
end

################################################################################
# Taskgraph Constructors used by this framework.
################################################################################
struct SimDumpConstructor <: AbstractTaskgraphConstructor
    name::String
    file::String
end

include("taskgraph.jl")

################################################################################
# Special Types for Placement Algorithms
################################################################################

# Simulated Annealing Placement.
# Special Tasks
