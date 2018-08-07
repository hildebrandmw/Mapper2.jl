
# Make an enum to indicate "Source" or "Sink". Move convenient that using symbols
"""
Enum indicating a direction. Values: `Source`, `Sink`.
"""
@enum Direction Source Sink

################################################################################
#                                  PORT TYPES                                  #
################################################################################

"Classification of port types."
@enum PortClass Input Output

struct Port
    name        ::String

    "The class of this port. Must be a [`PortClass`](@ref)'"
    class       ::PortClass
    metadata    ::Dict{String,Any}

    Port(name, class::PortClass; metadata = emptymeta()) = new(name, class, metadata)
end

const _port_compat = Dict(
    Source => (Input,),
    Sink => (Output,),
)

const _port_inverses = Dict(
    Input => Output,
    Output => Input,
)

"""
$(SIGNATURES)

Return `true` if `port` is the correct class for the given [`Direction`](@ref)
"""
checkclass(port::Port, direction::Direction) = port.class in _port_compat[direction]

"""
$(SIGNATURES)

Return a version of `port` with the class inverted.
"""
invert(port::Port) = Port(port.name, _port_inverses[port.class]; metadata = port.metadata)

############
# Port Doc #
############
@doc """
Port type for modeling input/output ports of a `Component`.

API
---
* [`checkclass`](@ref)
* [`invert`](@ref)
""" Port

################################################################################
#                                  LINK TYPE                                   #
################################################################################

struct Link
    name :: String
    sources :: Vector{Path{Port}}
    dests :: Vector{Path{Port}}
    metadata :: Dict{String,Any}

    function Link(name, srcs::T, dsts::T, metadata) where T <: Vector{Path{Port}}
        return new(name,srcs,dsts,Dict{String,Any}(metadata))
    end
end

"""
$(SIGNATURES)

Return [`Vector{Path{Port}}`](@ref Path) of sources for `link`.
"""
sources(link::Link) = link.sources

"""
$(SIGNATURES)

Return [`Vector{Path{Port}}`](@ref Path) of destinations for `link`.
"""
dests(link::Link)   = link.dests

############
# Link Doc #
############
@doc """
    struct Link{P <: AbstractComponentPath}

Link data type for describing which ports are connected. Can have multiple
sources and multiple sinks.

API
---
* [`sources`](@ref)
* [`dests`](@ref)
""" Link

################################################################################
#                               COMPONENT TYPES                                #
################################################################################

# Master abstract type from which all component types will subtype
abstract type AbstractComponent end

"Return an iterator for the children within a component."
children(c::AbstractComponent) = values(c.children)
childnames(component::AbstractComponent) = keys(component.children)
"Return an iterator for links within the component."
links(c::AbstractComponent) = values(c.links)

#-------------------------------------------------------------------------------
# Component
#-------------------------------------------------------------------------------
"""
Basic building block of architecture models. Can be used to construct
hierarchical models.
"""
struct Component <: AbstractComponent
    name :: String
    primitive :: String
    "Sub-components of this component. Indexed by instance name."
    children :: Dict{String, Component}
    "Ports instantiated directly by this component. Indexed by instance name."
    ports :: Dict{String, Port}
    "Links instantiated directly by this component. Indexed by instance name."
    links :: Dict{String, Link}
    """
    Record of the `Link` (by name) attached to a `Port`, keyed by `Path{Port}`.
    Length of each `Path{Port}` must be 1 or 2, to reference ports either
    instantiated by this component directly, or by one of this component's
    immediate children.j
    """
    portlink :: Dict{Path{Port}, Link}

    """
    `Dict{String,Any}` for holding any extra data needed by the user.
    """
    metadata :: Dict{String, Any}
end

function Component(
        name;
        primitive   ::String = "",
        metadata = Dict{String, Any}(),
    )

    children    = Dict{String, Component}()
    ports       = Dict{String, Port}()
    links       = Dict{String, Link}()
    portlink    = Dict{Path{Port}, String}()

    # Return the newly constructed type.
    return Component(
        name,
        primitive,
        children,
        ports,
        links,
        portlink,
        metadata,
    )
end

# Promote types for paths
path_promote(::Type{Component}, ::Type{T}) where T <: Union{Port,Link} = T
path_demote(::Type{T}) where T <: Union{Component,Port,Link} = Component

# String macros for constructing port and link paths.
macro component_str(s) :(Path{Component}($s)) end
macro link_str(s) :(Path{Link}($s)) end
macro port_str(s) :(Path{Port}($s)) end

function relative_port(component::AbstractComponent, portpath::Path{Port})
    # If the port is defined in the component, just return the port itself
    if length(portpath) == 1
        return component[portpath]
    # If the port is defined one level down in the component hierarchy,
    # extract the port from the level and "invert" it so the directionality
    # of the port is relative to the component "c"
    elseif length(portpath) == 2
        return invert(component[portpath])
    else
        error("Invalid relative port path $portpath for component $(component.name)")
    end
end


#-------------------------------------------------------------------------------
ports(c::Component) = values(c.ports)
ports(c::Component, classes) = Iterators.filter(x -> x.class in classes, values(c.ports))

portpaths(component) = [Path{Port}(name) for name in keys(component.ports)]
function portpaths(component, classes)
    [Path{Port}(k) for (k,v) in component.ports if v.class in classes]
end
connected_ports(a::AbstractComponent) = collect(keys(a.portlink))

@doc """
    ports(component, [classes])

Return an iterator for all the ports of the given component. Ports of children
are not given. If `classes` are provided, only ports matching the specified
classes will be returned.
""" ports

@doc """
    portpaths(component, [classes])::Vector{Path{Port}}

Return `Path`s to all ports immediately instantiated in `component`.
""" portpaths

#------------------------------------------------------------------------------
# TopLevel
#-------------------------------------------------------------------------------
"""
Top level component for an architecture mode. Main difference is between a
`TopLevel` and a `Component` is that children of a `TopLevel` are accessed
via address instead of instance name. A `TopLevel` also does not have any
ports of its own.

Parameter `D` is the dimensionality of the `TopLevel`.
"""
struct TopLevel{D} <: AbstractComponent

    name :: String

    "Direct children of the `TopLevel`, indexed by instance name."
    children :: Dict{String, Component}

    "Translation from child instance name to the `Address` that child occupies."
    child_to_address :: Dict{String, Address{D}}

    "Translation from `Address` to the `Component` at that address."
    address_to_child :: Dict{Address{D}, String}

    "`Link`s instantiated directly by the `TopLevel`."
    links :: Dict{String, Link}

    "Record of which `Link`s are attached to which `Port`s. Indexed by `Path{Port}."
    portlink :: Dict{Path{Port}, Link}
    metadata :: Dict{String, Any}

    # --Constructor
    function TopLevel{D}(name, metadata = Dict{String,Any}()) where D
        # Create a bunch of empty items.
        links           = Dict{String, Link}()
        portlink        = Dict{Path{Port}, Link}()
        children        = Dict{String, Component}()
        child_to_address = Dict{String, Address{D}}()
        address_to_child = Dict{Address{D}, String}()

        return new{D}(
            name,
            children,
            child_to_address,
            address_to_child,
            links,
            portlink,
            metadata
        )
    end
end

################################################################################
# Convenience methods.
################################################################################

isgloballink(p::Path{Link}) = length(p) == 1
isgloballink(p::Path) = false

isglobalport(p::Path{Port}) = length(p) == 2
isglobalport(p::Path) = false

Base.string(::Type{Component})  = "Component"
Base.string(::Type{Port})       = "Port"
Base.string(::Type{Link})       = "Link"

"""
$(SIGNATURES)

Return an iterator of all addresses with subcomponents in `toplevel`.
"""
addresses(toplevel::TopLevel) = keys(toplevel.address_to_child)
portpaths(toplevel::TopLevel) = Vector{Path{Port}}()


"""
    getaddress(item)

Single argument version: Return an address encapsulated in `item`.

    getaddress(item, index)

Get an address from `item` referenced by `index`.

Method List
-----------
$(METHODLIST)
"""
function getaddress end

"""
    hasaddress(toplevel, path)

Return `true` if the item referenced by `path` has an `Address`.
"""
function hasaddress end

"""
    isaddress(toplevel, address)

Return `true` if `address` exists in `toplevel`.
"""
function isaddress end


getaddress(toplevel::TopLevel, path::Path) = getaddress(toplevel, first(path))
getaddress(toplevel::TopLevel, str::String) = toplevel.child_to_address[str]
hasaddress(toplevel::TopLevel, path::Path) = hasaddress(toplevel, first(path))
hasaddress(toplevel::TopLevel, str::String) = haskey(toplevel.child_to_address, str)
isaddress(toplevel, address) = haskey(toplevel.address_to_child, address)

getname(toplevel::TopLevel, a::Address) = toplevel.address_to_child[a]
function Base.size(t::TopLevel{D}) where D
    return dim_max(addresses(t)) .- dim_min(addresses(t)) .+ Tuple(1 for _ in 1:D)
end

"""
    fullsize(toplevel, ruleset)


"""
function fullsize(toplevel::TopLevel{D}, ruleset::RuleSet) where {D}
    # Step 1: Compute the span of addresses.
    address_iter = addresses(toplevel)
    span = dim_max(address_iter) .- dim_min(address_iter) .+ Tuple(1 for _ in 1:D)

    # Run through all addresses of this toplevel. If there is more than one
    # mappable component in a given address, we need to add a dimension to 
    # account for that.
    max_mappables = maximum((length ∘ mappables)(toplevel, ruleset, addr) for addr in address_iter)
    if max_mappables > 1
        return (max_mappables, span...)
    else
        return span
    end
end

#-------------------------------------------------------------------------------
# Various overloadings of the method "getindex"
#-------------------------------------------------------------------------------

function Base.getindex(c::AbstractComponent, p::Path{T}) where T <: Union{Port,Link}
    length(p) == 0 && error("Paths to Ports and Links must have non-zero length")

    c = descend(c, p.steps, length(p)-1)
    return gettarget(c, T, last(p))
end

Base.getindex(c::AbstractComponent, p::Path{Component}) = descend(c, p.steps, length(p))
Base.getindex(c::AbstractComponent, s::Address) = c.children[c.address_to_child[s]]
function descend(c::AbstractComponent, steps::Vector{String}, n::Integer)
    for i in 1:n
        c = c.children[steps[i]]
    end
    return c
end

gettarget(c::Component, ::Type{Port}, target) = c.ports[target]
gettarget(c::AbstractComponent, ::Type{Link}, target) = c.links[target]


@doc """
    getindex(component, path::Path{T})::T where T <: Union{Port,Link,Component}

Return the architecture type referenced by `path`. Error horribly if `path` does
not exist.

    getindex(toplevel, address)::Component

Return the top level component of `toplevel` at `address`.
""" getindex

################################################################################

"""
    walk_children(component::AbstractComponent, [address]) :: Vector{Path{Component}}

Return relative paths to all the children of `component`. If `address` is given
return relative paths to all components at `address`.
"""
function walk_children(component::AbstractComponent)
    # Recurse on all children.
    paths = Vector{Path{Component}}()
    for (name, child) in component.children
        # Recurse on all children - append each child's instance name in front
        # of the path.
        child_paths = catpath.(name, walk_children(child))
        append!(paths, child_paths)
    end
    # Append an empty path for this component.
    push!(paths, Path{Component}())
    return paths
end

function walk_children(toplevel::TopLevel, address::Address)
    # Walk the component at this address
    paths = walk_children(toplevel[address])
    component_name = toplevel.address_to_child[address]
    # Append the first part of the component path to each of the sub paths.
    return catpath.(component_name, paths)
end

function connected_components(tl::TopLevel{D}) where D
    # Construct the associative for the connected components.
    # Use a set to automatically deal with duplicates.
    cc = Dict{Address{D}, Set{Address{D}}}()
    # Iterate through all links - record adjacency information
    for link in links(tl)
        for source_port in sources(link), sink_port in dests(link)
            src_address = getaddress(tl, source_port)
            snk_address = getaddress(tl, sink_port)

            push_to_dict(cc, src_address, snk_address)
        end
    end
    # Default unseen addresses to an empty set of addresses.
    for address in addresses(tl)
        if !haskey(cc, address)
            cc[address] = Set{Address{D}}()
        end
    end
    return cc
end

################################################################################
# METHODS FOR NAVIGATING THE HIERARCHY
################################################################################
function search_metadata(c::AbstractComponent, key, value, f::Function = ==)::Bool
    return haskey(c.metadata, key) ? f(value, c.metadata[key]) : false
end
search_metadata(c::AbstractComponent, key) = haskey(c.metadata, key)

function search_metadata!(c::AbstractComponent, key, value, f::Function = ==)
    # check top component
    search_metadata(c, key, value, f) && return true
    # recursively call search_metadata! on all subcomponents
    for child in values(c.children)
        search_metadata!(child, key, value, f) && return true
    end
    return false
end

function get_metadata!(c::AbstractComponent, key)
    if haskey(c.metadata, key)
        return c.metadata[key]
    end

    for child in values(c.children)
        val = get_metadata!(child, key)
        if val != nothing
            return val
        end
    end

    return nothing
end

################################################################################
# ASSERTION METHODS.
################################################################################

function assert_no_children(c::AbstractComponent)
    passed = true
    if length(c.children) != 0
        passed = false
        @error "Cmponent $(c.name) is not expected to have any children."
    end
    return passed
end

assert_no_intrarouting(c::AbstractComponent) = length(c.links) == 0
isfree(c::AbstractComponent, p::Path{Port}) = !haskey(c.portlink, p)

################################################################################
# Documentation for TopLevel
################################################################################

@doc """
    connected_components(toplevel::TopLevel{A,D})::Dict{Address{D}, Set{Address{D}}

Return `d` where key `k` is a valid address of `tl` and where `d[k]` is the set
of valid addresses of `tl` whose components are the destinations of links
originating at address `k`.
""" connected_components

@doc """
    search_metadata(c::AbstractComponent, key, value, f::Function = ==)

Search the metadata of field of `c` for `key`. If `c.metadata[key]` does not
exist, return `false`. Otherwise, return `f(value, c.metadata[key])`.
""" search_metadata

@doc """
    search_metadata!(c::AbstractComponent, key, value, f::Function = ==)

Call `search_metadata` on each subcomponent of `c`. Return `true` if function
call return `true` for any subcomponent.
""" search_metadata!
