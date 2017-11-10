module Mapper2

using IterTools
using DataStructures
using LightGraphs
using ProgressMeter
using Formatting


import Base.==
export Address, Port, Component, benchmark

# Set up directory paths
const SRCDIR = @__DIR__
const PKGDIR = dirname(SRCDIR)

# Flag for debug mode
const DEBUG     = true
const USEPLOTS  = true

import Base: start, next, done

# Colors for printing information.
const colors = Dict(
    # Start of a major operation.
    :start      => :cyan,
    # Start of a minor operation.
    :substart   => :light_cyan,
    # Completion of a major operation.
    :done  => :light_green,
    # Completion of a minor operation.
    :info  => :yellow,
    # More critical info.
    :warning => 202,
    # Something went wrong.
    :error   => :red,
    # Something was successful.
    :success => :green,
    # Normal print.
    :none    => :white,
)
debug_print(sym::Symbol, args...) = print_with_color(colors[sym],args...)

###############################
# Common types and operations #
###############################
include("Common/Address.jl")
include("Common/Helper.jl")
# Architecture modeling related files.
include("Architecture/Architecture.jl")
include("Architecture/Constructors.jl")
# Taskgraph related files
include("Taskgraph/Taskgraph.jl")
# Top-level Map datatype
include("Map/Map.jl")
include("Map/Save.jl")
include("Map/Inspection.jl")

#############
# Placement #
#############

include("Placement/Place.jl")

###########
# Routing #
###########
include("Routing/Routing.jl")

############
# Plotting #
############
# Optionally include plotting. Mapper will start up faster if plotting is turned
# off because Plots takes a while to load.
if USEPLOTS
    #include("Plots/Plots.jl")
    include("Plots/Plots3d.jl")
end
################################################################################
# Frameworks
################################################################################
include("Frameworks/Kilocore/Kilocore.jl")

################################################################################
# Misc Includes
################################################################################

# Profile Routines
#include("benchmark.jl")

function testmap()
    options = Dict{Symbol, Any}()
    debug_print(:start, "Building Architecture\n")
    #arch = build_asap4()
    #arch = build_asap4(A = KCLink)
    #arch = build_asap3()
    #arch  = build_asap3(A = KCLink)
    dict = initialize_mem_dict()
    arch = build_generic(33,33,2,dict, A = KCLink)
    sdc   = SimDumpConstructor("fft")
    debug_print(:start, "Building Taskgraph\n")
    taskgraph = Taskgraph(sdc)
    tg    = apply_transforms(taskgraph, sdc)
    return NewMap(arch, tg)
end

function initialize_mem_dict()
    # initialize memory addr and memory neighbor addr
    mem_dict = Dict(  Address(34,2,1)  => [Address(33,2,1),  Address(33,3,1)],
                      Address(34,4,1)  => [Address(33,4,1),  Address(33,5,1)],
                      Address(34,6,1)  => [Address(33,6,1),  Address(33,7,1)],
                      Address(34,8,1)  => [Address(33,8,1),  Address(33,9,1)],
                      Address(34,10,1) => [Address(33,10,1), Address(33,11,1)],
                      Address(34,12,1) => [Address(33,12,1), Address(33,13,1)],
                      Address(34,14,1) => [Address(33,14,1), Address(33,15,1)],
                      Address(34,16,1) => [Address(33,16,1), Address(33,17,1)],
                      Address(34,18,1) => [Address(33,18,1), Address(33,19,1)],
                      Address(34,20,1) => [Address(33,20,1), Address(33,21,1)],
                      Address(34,22,1) => [Address(33,22,1), Address(33,23,1)],
                      Address(34,24,1) => [Address(33,24,1), Address(33,25,1)],
                      Address(34,26,1) => [Address(33,26,1), Address(33,27,1)] )
    dict = Dict{String,Any}()
    # move to a bigger dict
    dict["memory_dict"] = mem_dict
    return dict
end

function slow_run(m, savename)
    # build the sa structure
    sa = SAStruct(m)
    # Run placement
    place(sa,
          move_attempts = 300000,
          warmer = DefaultSAWarm(0.95, 1.1, 0.99),
          cooler = DefaultSACool(0.999),
         )
    record(m, sa)
    save(m, savename)
end

end #module Mapper2
