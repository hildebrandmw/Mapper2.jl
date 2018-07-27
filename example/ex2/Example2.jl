module Example2

using Mapper2

export  build_primitive,
        build_tile,
        build_arch,
        # taskgraph
        make_taskgraph,
        make_map


struct Test3d <: Architecture end

make_map() = Map(build_arch(), make_taskgraph())
        
include("Architecture.jl")
include("Taskgraph.jl")
include("Placement.jl")

end#module Example2
