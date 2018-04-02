"""
    softcopy(c::T) where T <: AbstractComponent

Create a copy of `c` where:

* Field `metadata` is deep copied.
* Field `children` is copied recursively using `softcopy`.
* All other fields are copied by sharing a reference.

This allows efficient instantiation of a component multiple times while still
allowing each component to have unique metadata.
"""
function softcopy(c::T) where T <: AbstractComponent
    # Iterate over all fieldnames. Don't make @generated to avoid having a
    # recursive @generated function.
    ex = map(fieldnames(T)) do f
        if f == :children
            return Dict(k => softcopy(v) for (k,v) in getfield(c,f))
        elseif f == :metadata
            return deepcopy(getfield(c,f))
        else
            return getfield(c,f)
        end
    end
    return T(ex...)
end

"""
    check(c::AbstractComponent)

Check a component for ports that are not connected to any link. Only applies
to ports visible to the level of hierarchy of `c`. That is, children of `c` will
not be checked.

Returns a `Vector{PortPath}` of unused ports.
"""
function check(c::AbstractComponent)
    # Gather all visible ports of `c` and all connected visible ports of `c`.
    # The unused ports are just the set diference.
    all_ports  = get_visible_ports(c)
    used_ports = connected_ports(c)

    unused_ports = setdiff(all_ports, used_ports)

    # Debug printing
    if length(unused_ports) > 0
        n_unused = length(unused_ports)
        @debug "Component $(c.name) has $(n_unused) unused ports."
        for port in unused_ports
            @debug "Unconnected: $port"
        end
    end
    return unused_ports
end

################################################################################
# get_visible_ports

function get_visible_ports(c::Component)
    portpaths = PortPath.(portnames(c))
    for (name,child) in c.children
        for port in portnames(child)
            path = PortPath(port, ComponentPath(name))
            push!(portpaths, path)
        end
    end
    return portpaths
end

function get_visible_ports(t::TopLevel{A,D}) where {A,D}
    portpaths = PortPath{AddressPath{D}}[]
    for (address,child) in t.children
        for port in portnames(child)
            path = PortPath(port, AddressPath{D}(address))
            push!(portpaths, path)
        end
    end
    return portpaths
end

@doc """
    get_visible_ports(a::AbstractComponent)

Return `Vector{PortPath}` of the ports of `a` and the ports of the children of `a`.
""" get_visible_ports

################################################################################
# BFS Routines for building the distance look up table
################################################################################
function build_distance_table(architecture::TopLevel{A,D}) where {A,D}
    # The data type for the LUT
    dtype = UInt8
    # Pre-allocate a table of the right dimensions.
    # Replicate the dimensions once to get a 2D sized LUT.
    dims = dim_max(addresses(architecture))
    distance = fill(typemax(dtype), dims..., dims...)

    neighbor_table = build_neighbor_table(architecture)

    @debug "Building Distance Table"
    # Run a BFS for each starting address
    for address in addresses(architecture)
        bfs!(distance, address, neighbor_table)
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

# Implementation note:
# This function is only correct if the cost of each link is 1. If cost can vary,
# will have to code this using some kind of shortest path formulation.
function bfs!(distance::Array{U,N}, source::CartesianIndex{D}, neighbor_table) where {U,N,D}
    # Create a queue for visiting addresses. Add source to get into the loop.
    q = Queue(CostAddress{U,D})
    enqueue!(q, CostAddress(zero(U), source))

    # Create a set of visited items to avoid visiting the same address twice.
    seen = Set{CartesianIndex{D}}()
    push!(seen, source)

    # Basic BFS.
    while !isempty(q)
        u = dequeue!(q)
        distance[source, u.address] = u.cost
        for v in neighbor_table[u.address]
            if v ∉ seen
                enqueue!(q, CostAddress(u.cost + one(U), v))
                push!(seen, v)
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
    # Extract the port type of the top level definition.
    port = t[portpath] 

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

################################################################################
# isconnected
################################################################################


# Default to false
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

@doc """
    isconnected(t::TopLevel, a::AbstractPath, b::AbstractPath)

Return `true` if architectural component referenced by path `a` is 
architecturally connected to that referenced by path `b`. 

The order of the arguments is important for directed components. For example,
if `a` references a port that is a source for link `b` in `t::TopLevel`, then

```julia
julia> isconnected(t, a, b)
true

julia> isconnected(t, b, a)
false
```

If one of `a` or `b` is of type `ComponentPath`, then only ports are considered
connected.
""" isconnected
