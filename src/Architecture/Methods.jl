
################################################################################
# BFS Routines for building the distance look up table
################################################################################
function build_distance_table(architecture::TopLevel{A,D}) where {A,D}
    # The data type for the LUT
    dtype = UInt8
    # Pre-allocate a table of the right dimensions.
    dims = dim_max(addresses(architecture))
    # Replicate the dimensions once to get a 2D sized LUT.
    distance = fill(typemax(dtype), dims..., dims...)
    # Get the neighbor table for finding adjacent components in the top level.
    neighbor_table = build_neighbor_table(architecture)

    @debug "Building Distance Table"
    # Run a BFS for each starting address
    for address in addresses(architecture)
        bfs!(distance, architecture, address, neighbor_table)
    end
    return distance
end

#=
Simple data structure for keeping track of costs associated with addresses
Gets put the the queue for the BFS.
=#
struct CostAddress{U,D}
    cost::U
    address::CartesianIndex{D}
end

function bfs!(distance::Array{U,N}, architecture::TopLevel{A,D},
              source::CartesianIndex{D}, neighbor_table) where {U,N,A,D}
    # Create a queue for visiting addresses.
    q = Queue(CostAddress{U,D})
    # Add the source addresses to the queue
    enqueue!(q, CostAddress(zero(U), source))

    # Create a set of visited items and add the source to that set.
    queued_addresses = Set{CartesianIndex{D}}()
    push!(queued_addresses, source)
    # Begin BFS - iterate until the queue is empty.
    while !isempty(q)
        u = dequeue!(q)
        distance[source, u.address] = u.cost
        for v in neighbor_table[u.address]
            if v ∉ queued_addresses
                enqueue!(q, CostAddress(u.cost + one(U), v))
                push!(queued_addresses, v)
            end
        end
    end
    return nothing
end

function build_neighbor_table(architecture::TopLevel{A,D}) where {A,D}
    @debug "Building Neighbor Table"
    # Get the connected component dictionary
    cc = MapperCore.connected_components(architecture)
    # Create a big list of lists
    #neighbor_table = Array{Vector{CartesianIndex{D}}}(dims)
    neighbor_table = Dict{CartesianIndex{D},Vector{CartesianIndex{D}}}()
    for (address, set) in cc
        neighbor_table[address] = collect(set)
    end
    return neighbor_table
end

################################################################################
# Connectedness methods.
################################################################################

function connectedlink(t::TopLevel, portpath::PortPath, dir::Symbol)
    port = t[portpath] 
    # Decide which case to use to access the connected link.
    if dir == :input
        up_one = port.class == "input"
    elseif dir == :output
        up_one = port.class == "output"
    else
        throw(DomainError())
    end

    if up_one
        # Must check one higher level of hierarchy.
        componentpath, rel_portpath = split(portpath, 2)
        # Get the component that declares the link connected to the port.
        component = t[componentpath]
        # Look pu the link in the dictionary 
        link = get(component.port_link, rel_portpath, LinkPath())
        # Prefix the component path to the link.
        return pushfirst(LinkPath(link), componentpath)
    else
        componentpath = prefix(portpath)
        # Get the link connected to the port.
        link = port.link
        return pushfirst(link, componentpath)
    end
end

function connectedports(t::TopLevel, linkpath, dir::Symbol)
    link = t[linkpath]
    # Check directionality
    if dir == :input
        linkiter = link.sources
    elseif dir == :output
        linkiter = link.sinks
    else
        throw(DomainError())
    end
    # Treat global links differently.
    isgloballink(linkpath) && (return linkiter)
    linkprefix = prefix(linkpath)
    return [pushfirst(i, linkprefix) for i in linkiter]
end

isconnected(t::TopLevel, a::AbstractPath, b::AbstractPath) = false

function isconnected(t::TopLevel, portpath::PortPath, linkpath::LinkPath)
    # Get the output link connected to the port
    actuallink = connectedlink(t, portpath, :output)
    if linkpath != actuallink
        @error """
            $portpath is not connected to $linkpath.

            It is connected to $actuallink.
            """
        return false
    end
    actualports = connectedports(t, linkpath, :input)
    if portpath ∉ actualports
        @error """
            $linkpath is not connected to $portpath.

            Actual sink ports: $actualports.
            """
    end
    return true
end

function isconnected(t::TopLevel, linkpath::LinkPath, portpath::PortPath)
    # Get the output link connected to the port
    actuallink = connectedlink(t, portpath, :input)
    if linkpath != actuallink
        @error """
            $portpath is not connected to $linkpath.

            It is connected to $actuallink.
            """
        return false
    end
    actualports = connectedports(t, linkpath, :output)
    if portpath ∉ actualports
        @error """
            $linkpath is not connected to $portpath.

            Actual sink ports: $actualports.
            """
    end
    return true
end

function isconnected(t::TopLevel, portpath::PortPath, cpath::AddressPath)
    component = t[cpath]
    cports = portnames(component, ("input",)) 
    cportpaths = [pushfirst(PortPath(c), cpath) for c in cports]
    if portpath ∉ cportpaths
        @error "$portpath is not an input of $cpath."
        return false
    end
    return true
end

function isconnected(t::TopLevel, cpath::AddressPath, portpath::PortPath)
    component = t[cpath]
    cports = portnames(component, ("output",))
    cportpaths = [pushfirst(PortPath(c), cpath) for c in cports]
    if portpath ∉ cportpaths
        @error "$portpath is not an input of $cpath."
        return false
    end
    return true
end
