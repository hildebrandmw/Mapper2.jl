module MapType

using GZip
using JSON
using DataStructures

using ..Mapper2: Addresses, Helper, Taskgraphs, Architecture

export  Map,
        Mapping,
        NewMap,
        NodeMap,
        EdgeMap,
        save,
        load

include("Map.jl")
include("Save.jl")
include("Inspection.jl")

end
