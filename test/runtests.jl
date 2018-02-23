using Mapper2
using Base.Test

# Add path to example architecture to the LOAD_PATH variable
for i in 1:2
    push!(LOAD_PATH, joinpath(Mapper2.PKGDIR, "example", "ex$i"))
end

include("Address.jl")
include("Architecture.jl")
include("IntegrationTest.jl")
include("SaveLoad.jl")
