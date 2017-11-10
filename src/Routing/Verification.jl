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


function check_resource_usage(m::Map{A,D},
                              rs::RoutingStruct,
                              errors) where {A,D}
    # Verify the specified capacity requirements are satisfied.
    check_congestion(m, rs, errors)
    # TODO - check if the architecture is OKAY with the connections using
    # each link.
end

function check_congestion(m::Map, rs::RoutingStruct, errors)
    link_info = rs.link_info
    # Reverse the portmap and linkmap dictionaries for better error messages.
    portmap_rev = rev_dict_safe(get_portmap(rs))
    linkmap_rev = rev_dict_safe(get_linkmap(rs))
    # Enumerate through all links.
    for (i,link) in enumerate(link_info)
        # If a link is congested, register the error.
        if iscongested(link)
            routing_congested_link_error(errors, i, portmap_rev, linkmap_rev)
        end
    end
    # Enumerate through all paths.
    for (i, path) in enumerate(getpaths(rs))
        if iscongested(rs, path)
            routing_congested_path_error(errors, gettaskgraph(m), i) 
        end
    end
end

function check_paths(m::Map{A,D}, rs::RoutingStruct, errors) where {A,D}
    # Unpack the structures.
    architecture    = getarchitecture(m)
    taskgraph       = gettaskgraph(m)
    resource_graph  = rs.resource_graph
    paths           = getpaths(rs)
    # Reverse the portmap and linkmap dictionaries.
    portmap_rev = rev_dict_safe(get_portmap(resource_graph))
    linkmap_rev = rev_dict_safe(get_linkmap(resource_graph))
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


#= TODO: Make this way better. =#
function walkpath(architecture::TopLevel{A,D},
                  path,
                  taskedge::TaskgraphEdge,
                  errors) where {A,D}

    # Check the validity of start nodes.
    for source_port_path in first(path)
        if !isvalid_source_port(A, architecture[source_port_path], taskedge)
            routing_invalid_port(errors, source_port_path, taskedge, :source)
        end
    end
    # Check the validity of stop nodes.
    for sink_port_path in last(path)
        if !isvalid_sink_port(A, architecture[sink_port_path], taskedge)
            routing_invalid_port(errors, sink_port_path, taskedge, :sink)
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
                routing_order_error(errors, path, i, LinkPath, PortPath)
            end
            if length(path[i+1]) != 1
                routing_length_error(errors, path, i, 1)
            end
            # Get the link
            linkpath = first(path[i+1])
            local success
            for portpath in thispath
                success = check_connectivity(architecture, portpath, linkpath, :source)
                success && break
            end
            # Record any errors
            if !success
                routing_invalid_connection(errors, thispath, linkpath)
                increment(errors)
                push!(errors.invalid_port_to_link, (thispath, linkpath))
            end
        elseif eltype(thispath) <: LinkPath
            # Make sure a PortPath collection follows this LinkPath collection.
            if !(eltype(path[i+1]) <: PortPath)
                routing_order_error(errors, path, i, PortPath, LinkPath)
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
                routing_invalid_connection(error, linkpath, thispath)
            end
        end
    end
end



################################################################################
# Routing Error Log Entries.
################################################################################
abstract type RoutingException <: Exception end

mutable struct RoutingErrors
    num_errors::Int64
    logs::Vector{Any}
    function RoutingErrors()
        return new(
            0,       # num_errors
            Any[],   # logs
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

struct RoutingOrderError;           key::Any; end
struct RoutingLengthError;          key::Any; end
struct RoutingCongestedLinkError;   key::Any; end
struct RoutingCongestedPathError;   key::Any; end
struct RoutingInvalidPort;          key::Any; end
struct RoutingInvalidConnection;    key::Any; end

function routing_order_error(errors, path, index, expected, recieved)
    increment(errors)
    log_entry = RoutingOrderError("""
    Expected path variable to be $expected. Got $recieved.
    Path: $(path)

    Offending Paths:
    $(path[index])
    $(path[index+1])
    """)
    push!(error.logs, log_entry)
end

function routing_length_error(errors, path, index, expected)
    increment(errors)
    log_entry = RoutingLengthError("""
    LinkPath collections should only have length of $expected.
    Path: $(path)

    Offending Paths:
    $(path[index+1])
    """)
    push!(errors.logs, log_entry)
    return nothing
end

function routing_congested_link_error(errors, index, portmap_rev, linkmap_rev)
    increment(errors)
    # Get the path for the link from the reversed dictionaries.
    link_path = reverse_lookup(index, portmap_rev, linkmap_rev) 
    log_entry = RoutingCongestedLinkError(
    """
    Link index $index is congested. Name of this link $(link_path).
    """
     )
    push!(errors.logs, log_entry)
end
function routing_congested_path_error(errors, taskgraph::Taskgraph, i)
    increment(errors)
    # Get the sources and sinks for the congested path.
    sources = getsources(getedge(taskgraph, i)) 
    sinks   = getsinks(getedge(taskgraph, i))
    entry = RoutingCongestedPathError(
        """
        Path number $i is congested.
        Sources: $sources.
        Sinks: $sinks.
        """
     )
    push!(errors.logs, entry)
end

function routing_invalid_port(errors, port, taskedge, direction)
    increment(errors)
    entry = RoutingInvalidPort(
    """
    Port $port is an invalid $direction port for task edge with:
    Sources: $(taskedge.sources)
    Sinks: $(taskedge.sinks)
    """
    )
end
function routing_invalid_connection(errors, this, that)
    increment(errors)
    log = RoutingInvalidConnection(
        """
        Invalid connection from $this to $that.
        """
    )
end
