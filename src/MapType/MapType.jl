module MapType

using GZip
using JSON
using DataStructures

using ..Mapper2: Addresses, Helper, Taskgraphs, Architecture, Debug

export  Map,
        Mapping,
        NewMap,
        NodeMap,
        EdgeMap,
        getpath,
        save,
        load

include("Map.jl")
include("Save.jl")
include("Inspection.jl")

end
