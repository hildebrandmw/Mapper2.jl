module Mapper2

const is07 = VERSION > v"0.7.0-"

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
using Reexport

const Address = CartesianIndex
export Address

if is07
    # v0.7 hack
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
else
    # v0.6 logging
    using MicroLogging
    function set_logging(level)
        modules = (Mapper2.Helper,
                   Mapper2.MapperCore,
                   Mapper2.Place,
                   Mapper2.SA,
                   Mapper2.Routing,
                  )
        for m in modules
            configure_logging(m, min_level=level)
        end
    end
end

include("Helper.jl")
using .Helper
include("MapperCore.jl")

include("Place/Place.jl")
include("Place/SA/SA.jl")
include("Route/Route.jl")

# exports from Helper.
export  SparseDiGraph,
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
        make_lightgraph

# Use submodules to make exports visible.
@reexport using .MapperCore

#############
# PLACEMENT #
#############
@reexport using .Place
# Placement Algorithms
@reexport using .SA

# Default Placement Algorithm
Place.placement_routine(::Type{<:AbstractArchitecture}) = SA.place

###########
# ROUTING #
###########
@reexport using .Routing

end #module Mapper2
