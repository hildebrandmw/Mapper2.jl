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
    include("Plots/Plots.jl")
    #include("Plots/Plots3d.jl")
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
    dict = initialize_dict()
    arch = build_generic(15,16,4,dict, A = KCLink)
    sdc   = SimDumpConstructor("ldpc")
    debug_print(:start, "Building Taskgraph\n")
    taskgraph = Taskgraph(sdc)
    tg    = apply_transforms(taskgraph, sdc)
    return NewMap(arch, tg)
end

function initialize_dict()
    # initialize memory addr and memory neighbor addr
    mem_dict = mem_layout(15,16,12)
    dict = Dict{String,Any}()
    # move to a bigger dict
    dict["memory_dict"] = mem_dict
    dict["input_handler"] = 1
    println(dict)
    return dict
end

function mem_layout(row,col,count)
    row_spacing = floor((row-1)/(count/4)) #leave one row for input handler
    col_spacing = floor(col/(count/4))
    row_addr = Int64[]
    col_addr = Int64[]
    for i = 0:(count/4)-1
        push!(row_addr,(i*row_spacing)+4)
    end
    for i = 0:(count/4)-1
        push!(col_addr,(i*col_spacing)+4)
    end
    mem_dict = Dict{Mapper2.Address{3},Array{Mapper2.Address{3},1}}()
    for r in row_addr
        mem_addr = Address(r,1,1)
        memproc_addr = [Address(r,2,1),Address(r+1,2,1)]
        mem_dict[mem_addr] = memproc_addr
        mem_addr = Address(r,col+2,1)
        memproc_addr = [Address(r,col+1,1),Address(r+1,col+1,1)]
        mem_dict[mem_addr] = memproc_addr
    end
    for c in col_addr
        mem_addr = Address(1,c,1)
        memproc_addr = [Address(2,c,1),Address(2,c+1,1)]
        mem_dict[mem_addr] = memproc_addr
        mem_addr = Address(row+2,c,1)
        memproc_addr = [Address(row+1,c,1),Address(row+1,c+1,1)]
        mem_dict[mem_addr] = memproc_addr
    end

    return mem_dict
end


function slow_run(m, savename)
    # build the sa structure
    sa = SAStruct(m)
    # Run placement
    place(sa,
          move_attempts = 500000,
          warmer = DefaultSAWarm(0.95, 1.1, 0.99),
          cooler = DefaultSACool(0.999),
         )
    record(m, sa)
    save(m, savename)
end

end #module Mapper2
