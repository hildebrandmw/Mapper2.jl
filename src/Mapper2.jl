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
include("Addresses.jl")
include("Helper.jl")

include("Taskgraphs.jl")
include("Architecture/Architecture.jl")
include("MapType/MapType.jl")

include("Place/Place.jl")
include("Route/Route.jl")

# Use submodules to make exports visible.
using .Helper
@reexport using .Addresses
@reexport using .Taskgraphs
@reexport using .Architecture
@reexport using .MapType
@reexport using .Place
@reexport using .Routing

end #module Mapper2
