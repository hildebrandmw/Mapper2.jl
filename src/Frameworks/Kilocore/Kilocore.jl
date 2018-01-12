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

const _special_attributes = Set([
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
"Basic architecture - no weights on links"
struct KCBasic <: AbstractKC end
"Basic architecture with link weights"
struct KCLink  <: AbstractKC end

# Architectures
include("asap4.jl")
include("asap3.jl")
include("generic.jl")

# Include files
include("Taskgraph.jl")
include("Placement.jl")
include("Routing.jl")

# Custom save format for the Project Manager
include("MapDump.jl")
