module Mapper2

const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)
using Reexport

using Logging

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
# TODO: DO we really need these exports?
export Address, dim_max, dim_min, place!

# Use submodules to make exports visible.
@reexport using .MapperCore

#############
# PLACEMENT #
#############
# Placement Algorithms
@reexport using .SA

# Default Placement Algorithm
place!(map::Map; kwargs...) = SA.place!(map; kwargs...)

###########
# ROUTING #
###########
@reexport using .Routing

end #module Mapper2
