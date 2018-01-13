module MapType

using ..Mapper2: Addresses, Helper, Taskgraphs, Architecture, Debug

export  Map,
        Mapping,
        NewMap,
        NodeMap,
        EdgeMap,
        getpath

include("Map.jl")
include("Save.jl")
include("Inspection.jl")

end
