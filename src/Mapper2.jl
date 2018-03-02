module Mapper2

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
using Reexport

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
Place.placement_routine(::Type{<:AbstractArchitecture}) = SA.place

###########
# ROUTING #
###########
@reexport using .Routing


end #module Mapper2
