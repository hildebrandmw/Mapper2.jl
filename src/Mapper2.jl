module Mapper2

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
using Reexport

using MicroLogging

function set_logging(level)
    modules = (Mapper2.Architecture,
               Mapper2.Taskgraphs,
               Mapper2.MapType,
               Mapper2.Place,
               Mapper2.Routing,
              )
    for m in modules
        configure_logging(m, min_level=level)
    end
end

export oneofin, push_to_dict

###############################
# Common types and operations #
###############################
include("Helper.jl")
include("MapperCore.jl")

include("Place/Place.jl")
include("Place/SA/SA.jl")
include("Route/Route.jl")

# Use submodules to make exports visible.
@reexport using .MapperCore

#############
# PLACEMENT #
#############
@reexport using .Place
# Placement Algorithms
@reexport using .SA

# Default Placement Algorithm
Place.placement_routine(::Type{A}) where {A <: AbstractArchitecture} = SA.place

###########
# ROUTING #
###########
@reexport using .Routing


end #module Mapper2
