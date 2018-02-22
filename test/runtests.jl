using Mapper2
using Base.Test

# Add path to example architecture to the LOAD_PATH variable
push!(LOAD_PATH, joinpath(Mapper2.PKGDIR, "example"))

include("Architecture.jl")
include("IntegrationTest.jl")
include("SaveLoad.jl")
