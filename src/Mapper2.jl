module Mapper2

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
using Reexport

using Logging
function set_logging(level) 
    if level == :debug
        disable_logging(Logging.Debug-10)
    elseif level == :info
        disable_logging(Logging.Info-10)
    elseif level == :warn
        disable_logging(Logging.Warn-10)
    elseif level == :error
        disable_logging(Logging.Error-10)
    else
        throw(KeyError(level))
    end
end

# Aux modules
include("Helper.jl")
using .Helper

include("MapperGraphs.jl")

# Central data types.
include("MapperCore.jl")

# Placement modules
include("Place/SA/SA.jl")

# Routing modules
include("Route/Route.jl")

# exports from Helper.
export  Address,
        SparseDiGraph,
        has_vertex,
        add_vertex!,
        add_edge!,
        vertices,
        outneighbors,
        inneighbors,
        nv,
        source_vertices,
        sink_vertices,
        linearize,
        make_lightgraph,
        dim_max,
        dim_min,
        place!

# Use submodules to make exports visible.
@reexport using .MapperCore

#############
# PLACEMENT #
#############
# Placement Algorithms
@reexport using .SA

# Default Placement Algorithm
"""
    place!(map::Map{A}; kwargs...) where {A <: Architecture}

Run mutating placement on `map`. Defaults to SA.place!.
"""
place!(map::Map{<:Architecture}; kwargs...) = SA.place!(map; kwargs...)

###########
# ROUTING #
###########
@reexport using .Routing

end #module Mapper2
