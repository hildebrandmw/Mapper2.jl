module Example2

using Mapper2

export  build_primitive,
        build_tile,
        build_arch,
        # taskgraph
        make_taskgraph,
        make_map,
        place,
        route


struct Test3d <: AbstractArchitecture end

make_map() = NewMap(build_arch(), make_taskgraph())
        
include("Architecture.jl")
include("Taskgraph.jl")
include("Placement.jl")

end#module Example2
