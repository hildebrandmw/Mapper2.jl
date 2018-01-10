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
const USEPLOTS  = false

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

# Running from a script
function place_and_route(input_profile, output_file, appname)
    # Build the asap4 architecture
    arch = build_asap4(A = KCLink) 

    # Construct the taskgraph from the given profile file.
    sdc  = SimDumpConstructor{false}(appname, input_profile)
    taskgraph = Taskgraph(sdc)
    tg = apply_transforms(taskgraph, sdc)

    # Build a map
    m = NewMap(arch, tg)
    
    # Run Placement and routing
    m = (route ∘ place)(m)
    
    # Save the placement and routing information
    dump(m, output_file)
    return nothing
end

function testmap()
    options = Dict{Symbol, Any}()
    debug_print(:start, "Building Architecture\n")
    #arch = build_asap4()
    #arch = build_asap4(A = KCLink)
    #arch = build_asap3()
    arch  = build_asap3(A = KCLink)
    #arch = build_generic(15,16,4,initialize_dict(15,16,12), A = KCLink)
    sdc   = CachedSimDump("sort")
    debug_print(:start, "Building Taskgraph\n")
    taskgraph = Taskgraph(sdc)
    tg    = apply_transforms(taskgraph, sdc)
    return NewMap(arch, tg)
end

function get_maps()
    app = "ldpc"
    # Build up the architectures to test.
    generic_15_16_4    = build_generic(15,16,4, initialize_dict(15,16,12), A = KCLink)
    generic_16_16_4    = build_generic(16,16,4, initialize_dict(16,16,12), A = KCLink)
    generic_16_17_4    = build_generic(16,17,4, initialize_dict(16,17,12), A = KCLink)
    generic_17_17_4    = build_generic(17,17,4, initialize_dict(17,17,12), A = KCLink)
    generic_17_18_4    = build_generic(17,18,4, initialize_dict(17,18,12), A = KCLink)
    generic_18_18_4    = build_generic(18,18,4, initialize_dict(18,18,12), A = KCLink)
    generic_18_19_4    = build_generic(18,19,4, initialize_dict(18,19,12), A = KCLink)
    generic_19_19_4    = build_generic(19,19,4, initialize_dict(19,19,12), A = KCLink)

    # Add all of the architectures to an array.
    architectures = [generic_15_16_4,
                     generic_16_16_4,
                     generic_16_17_4,
                     generic_17_17_4,
                     generic_17_18_4,
                     generic_18_18_4,
                     generic_18_19_4,
                     generic_19_19_4]

    # Give names to each of the architectures - append the app name to
    # the front
    save_names = "$(app)_" .* ["generic_15_16_4",
                               "generic_16_16_4",
                               "generic_16_17_4",
                               "generic_17_17_4",
                               "generic_17_18_4",
                               "generic_18_18_4",
                               "generic_18_19_4",
                               "generic_19_19_4"]

    # Build the taskgraphs
    taskgraph_constructor = SimDumpConstructor(app)
    debug_print(:start, "Building Taskgraph\n")
    taskgraph = Taskgraph(taskgraph_constructor)
    taskgraph = apply_transforms(taskgraph, taskgraph_constructor)

    # Build the maps for each architecture/taskgraph pair.
    maps = NewMap.(architectures, taskgraph)

    return maps, save_names
end


function bulk_run()
    maps, save_names = get_maps()

    # Build an anonymous function to allow finer control of the placement
    # function.
    place_algorithm = m -> place(m,
          move_attempts = 500000,
          warmer = DefaultSAWarm(0.95, 1.1, 0.99),
          cooler = DefaultSACool(0.998),
         )

    # Execute the parallel run
    routed_maps = parallel_run(maps, save_names, place_algorithm = place_algorithm)

    return routed_maps
end

"""
    parallel_run(maps, save_names)

Place and route the given collection of maps in parallel. After routing,
all maps will be saved according to the respective entry in `save_names`.
"""
function parallel_run(maps, save_names; place_algorithm = m -> place(m))
    # Parallel Placement
    placed = pmap(place_algorithm, maps)
    # Parallel Routing
    routed = pmap(m -> route(m), placed)
    # Print out statistic for each run - also save everything.
    print_with_color(:yellow, "Run Statistics\n")
    for (m, name) in zip(routed, save_names)
        print_with_color(:light_cyan, name, "\n")
        report_routing_stats(m)
        save(m, name)
    end
    return routed
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

function shotgun(m::Map{A,D}, iterations; kwargs...) where {A,D}
    # Get the placement struct.
    placement_struct = get_placement_struct(m)
    structs = typeof(placement_struct)[]
    first = true
    local state
    for i = 1:iterations
        if first
            ps = deepcopy(placement_struct)
            state = place(ps; kwargs...)
            push!(structs, ps)
            first = false
        else
            ps = deepcopy(last(structs))
            state = place(ps; supplied_state = state,
                              kwargs...,
                              warmer = TrueSAWarm(),
                             )
            push!(structs, ps)
        end
    end

    first = true
    best  = 0
    for ps in structs
        # Record the placement.
        record(m, ps)
        # Run the routing protocol.
        routing_struct = RoutingStruct(m)
        algorithm = routing_algorithm(m, routing_struct)
        route(algorithm, routing_struct)
        # Continue if routing structure is congested
        iscongested(routing_struct) && continue
        tl = total_links(routing_struct)
        if first
            best = tl
            record(m, routing_struct)
            first = false
        else
            if best > tl
                best = tl
                record(m, routing_struct)
            end
        end
    end
    first == true && error()
    return m
end

end #module Mapper2
