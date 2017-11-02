#=
Methods for verifying a routing is consistent with the architecture to catch
bugs and writing the results of routing back to the Map data structure.
=#


################################################################################
# ROUTING VERIFICATION
#=
This routine is responsible for taking a routing structure `rs` post routing
and check the correctness of the routing with respect to the original
architecture. The following steps need to happen:

- For each routing resource, ensure that:
    * The capacity requirement for that resource is not violated.
    * The communication node mapped to that resource is in fact compatible
        with that resource. This will require architecture specific functions
        to be documented here.

- Traverse through all communication paths in the taskgraph. For each path, the
    following must be true:
    * The source port(s) and the destination port(s) must be valid source(s) and
        destination(s) for that communication path. This will require
        architecture specific callbacks.
    * Follow the path declared by the routing structure. Ensure that the path
        is valid given the base architecture model. This will be done in two
        stages:

        1. Try to follow the path using the declared links within a component.
        2. If this fails, try to obtain the routing graph for that component
        to determine if the path if feasible.

        Keep performing this crawl until the stop node is reached. If at any
        point the routing is deemed infeasible or illegal - report the problem
        for printing at the end.
=#
################################################################################
function verify_routing(m::Map{A,D}, rs::RoutingStruct) where {A,D}
    DEBUG && debug_print(:start, "Verifying Routing\n")
    # Create a new error tracker.
    errors = RoutingErrors()
    # Check routing Resources
    check_resource_usage(m, rs, errors)
    # Check paths
    check_paths(m, rs, errors)
    # Check for errors.
    if errors.num_errors > 0
        debug_print(:error, "Verification Failed!\n")
    else
        debug_print(:success, "Verification Passed\n")
    end
    return errors
end

mutable struct RoutingErrors
    num_errors::Int64
    congested_link_indices::Vector{Int64}
    congested_path_indices::Set{Int64}
    invalid_source_ports::Vector{Tuple{PortPath, TaskgraphEdge}}
    invalid_sink_ports::Vector{Tuple{PortPath, TaskgraphEdge}}
    invalid_port_to_link::Vector{Any}
    invalid_link_to_port::Vector{Any}
    logs::Vector{String}
    function RoutingErrors()
        return new(
            0,          # num_errors,
            Int64[],    # congested_link_indices
            Set{Int64}(),    # congested_path_indices
            Tuple{PortPath, TaskgraphEdge}[],   # invalid_source_ports
            Tuple{PortPath, TaskgraphEdge}[],   # invalid_sink_ports
            Any[],      # invalid_port_to_link
            Any[],      # invalid_link_to_port
            String[],   # logs
        )
    end
end

"""
    increment(errors::RoutingErrors)

Increment the number of errors found.
"""
function increment(errors::RoutingErrors)
    errors.num_errors += 1
    DEBUG && print_with_color(:red, "Errors Found: ", errors.num_errors,"\n")
    return nothing
end

function check_resource_usage(m::Map{A,D},
                              rs::RoutingStruct,
                              errors::RoutingErrors) where {A,D}
    # Unpack the structures.
    architecture    = m.architecture
    taskgraph       = m.taskgraph
    resource_graph  = rs.resource_graph
    link_info       = rs.link_info
    # Verify the specified capacity requirements are satisfied.
    check_congestion(link_info, errors)
    # Check paths
    check_paths(m, rs, errors)
end

function check_congestion(link_info, errors)
    # Enumerate through all links.
    for (i,link) in enumerate(link_info)
        # If a link is congested, register the error.
        if iscongested(link)
            increment(errors)
            push!(errors.congested_link_indices, i)
            push!(errors.congested_path_indices, values(getstate(link))...)
        end
    end
end

function check_paths(m::Map{A,D}, rs::RoutingStruct, errors::RoutingErrors) where {A,D}
    # Unpack the structures.
    architecture    = m.architecture
    taskgraph       = m.taskgraph
    resource_graph  = rs.resource_graph
    paths           = getpaths(rs)
    # Reverse the portmap and linkmap dictionaries.
    portmap_rev = rev_dict_safe(resource_graph.portmap)
    linkmap_rev = rev_dict_safe(resource_graph.linkmap)
    # Check all the paths.
    for (taskedge_index,path) in enumerate(paths)
        taskedge = getedge(taskgraph, taskedge_index) 
        # Get the ports/link paths from the reversed dictionaries.
        arch_paths = map(path) do i
            return haskey(portmap_rev,i) ? portmap_rev[i] : linkmap_rev[i]
        end
        walkpath(architecture, arch_paths, taskedge, errors) 
    end
end

#=
TODO: Clean up this error reporting. A lot.
=#
function walkpath(architecture::TopLevel{A,D},
                  path,
                  taskedge::TaskgraphEdge,
                  errors::RoutingErrors) where {A,D}
    # Check the validity of start nodes.
    for source_port_path in first(path)
        if !isvalid_source_port(A, architecture[source_port_path], taskedge)
            increment(errors)
            push!(errors.invalid_source_ports, (source_port_path, taskedge))
        end
    end
    # Check the validity of stop nodes.
    for sink_port_path in last(path)
        if !isvalid_sink_port(A, architecture[sink_port_path], taskedge)
            increment(errors)
            push!(errors.invalid_sink_ports, (sink_port_path, taskedge))
        end
    end

    #=
    Walk through each node on the path. If a path is a port path, make sure the
    next path is a link and that the port shows up in the sources for that link.
    =#
    for i = 1:length(path)-1
        # Get the collection of ports/link paths at this index of the walk
        # through the architecture.
        thispath = path[i]
        if eltype(thispath) <: PortPath
            if !(eltype(path[i+1]) <: LinkPath)
                increment(errors)
                log_entry = """
                Expected path variable following a PortPath to be a LinkPath.
                Path: $(path)

                Offending Paths:
                $(path[i])
                $(path[i+1])
                """
                push!(error.logs, log_entry)
            end
            if length(path[i+1]) != 1
                increment(errors)
                log_entry = """
                LinkPath collections should only have length of 1.
                Path: $(path)

                Offending Paths:
                $(path[i+1])
                """
            end
            # Get the link
            linkpath = first(path[i+1])
            # I
            local success
            for portpath in thispath
                success = check_connectivity(architecture, portpath, linkpath, :source)
                success && break
            end
            # Record any errors
            if !success
                increment(errors)
                push!(errors.invalid_port_to_link, (thispath, linkpath))
            end
        elseif eltype(thispath) <: LinkPath
            if length(thispath) != 1
                increment(errors)
                log_entry = """
                LinkPath collections should only have length of 1.
                Path: $(path)

                Offending Paths:
                $(path[i+1])
                """
            end
            #=
            Raise an error message if 
            =#
            if !(eltype(path[i+1]) <: PortPath)
                increment(errors)
                log_entry = """
                Expected path variable following a LinkPath to be a PortPath.
                Path: $(path)

                Offending Paths:
                $(path[i])
                $(path[i+1])
                """
                push!(error.logs, log_entry)
            end
            portpaths = path[i+1]
            linkpath = first(thispath)
            # Do the connectivity check
            for portpath in portpaths
                success = check_connectivity(architecture, portpath, linkpath, :sink)
                success && break
            end
            # Record any errors
            if !success
                increment(errors)
                push!(errors.invalid_link_to_port, (linkpath, thispath))
            end
        end
    end
end


