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
        @debug begin
            n_unused = length(unused_ports)
            str = "Component $(c.name) has $(n_unused) unused ports. $unused_ports"
        end
    end
    return unused_ports
end

################################################################################
# get_visible_ports

function get_visible_ports(c::Component)
    # Get ports defined at this level of hierarchy
    portpaths = [Path{Port}(i) for i in portnames(c)]
    # Collect all external ports of children.
    for (name,child) in c.children
        for port in portnames(child)
            path = Path{Port}([name, port])
            push!(portpaths, path)
        end
    end
    return portpaths
end

function get_visible_ports(t::TopLevel{A,D}) where {A,D}
    portpaths = Path{Port}[]

    for (name,child) in t.children
        for port in portnames(child)
            path = Path{Port}([name, port])
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
            in(v, seen) && continue

            enqueue!(q, CostAddress(u.cost + one(U), v))
            push!(seen, v)
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

function connectedlink(t::TopLevel, portpath::Path{Port}, dir::Symbol)
    # Extract the port type of the top level definition.
    port = t[portpath] 

    # If the port direction differs from "dir", then we must go up one level
    # in the component hierarchy to get the attached link.
    up_one = port.class == dir

    split_amount = up_one ? 2 : 1
    cpath, ppath = splitpath(portpath, split_amount)

    component = t[cpath]
    link = component.portlink[ppath]
    return catpath(cpath, Path{Link}(link.name))
end

function connectedports(t::TopLevel, linkpath, dir::Symbol)
    link = t[linkpath]
    # Check directionality
    if dir == :input
        linkiter = sources(link)
    elseif dir == :output
        linkiter = dests(link)
    else
        throw(DomainError())
    end
    # If the link is global, its sources and destinations are already full
    # address paths, just return these arrays directly.
    #
    # Otherwise, need to prefix the paths local to the link with the path to
    # the component where the links are defined.
    isgloballink(linkpath) && (return linkiter)
    linkprefix = striplast(linkpath)
    return [catpath(linkprefix, i) for i in linkiter]
end

################################################################################
# isconnected
################################################################################


# Default to false
function isconnected(t::TopLevel, a::Path, b::Path)
    @error "Undefined connection"
    return false
end

function isconnected(t::TopLevel, portpath::Path{Port}, linkpath::Path{Link})
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

function isconnected(t::TopLevel, linkpath::Path{Link}, portpath::Path{Port})
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

function isconnected(t::TopLevel, portpath::Path{Port}, cpath::Path{Component})
    component = t[cpath]
    cports = portnames(component, (:input,)) 
    cportpaths = [catpath(cpath, Path{Port}(c)) for c in cports]
    if portpath ∉ cportpaths
        @error "$portpath is not an input of $cpath."
        return false
    end
    return true
end

function isconnected(t::TopLevel, cpath::Path{Component}, portpath::Path{Port})
    component = t[cpath]
    cports = portnames(component, (:output,))
    cportpaths = [catpath(cpath, Path{Port}(c)) for c in cports]
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
