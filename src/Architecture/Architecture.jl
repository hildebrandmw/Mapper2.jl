"""
    AbstractArchitecture

Abstract supertype for controlling dispatch to specialized functions for
architecture interpretation. Create a custom concrete subtype of this if you
want to use custom methods during placement or routing.
"""
abstract type AbstractArchitecture end

abstract type AbstractPath end
abstract type AbstractComponentPath <: AbstractPath end

#-------------------------------------------------------------------------------
# Component Path
#-------------------------------------------------------------------------------
struct ComponentPath <: AbstractComponentPath
    path::Vector{String}
    ComponentPath(str::Vector{T}) where T <: AbstractString = new(String.(str))
end

#-- Constructors
ComponentPath() = ComponentPath(String[])
ComponentPath(str::String) = isempty(str) ? ComponentPath() :
                                            ComponentPath(split(str, "."))

@doc """
Data type for pointing to `Components` in a component hierarchy where the
top-most data type is a `Component`.

See also: [`AddressPath`](@ref AddressPath).

# Fields
* `path::Vector{String}` - Sequential instance ID's specificying which children
    to use to get to the final component.

# Constructors
```jldoctest
julia> ComponentPath("a.b.c") == ComponentPath(["a","b","c"])
true
```
""" ComponentPath

#julia> ComponentPath() == ComponentPath(String[]) == ComponentPath("")
#true

#-------------------------------------------------------------------------------
# AddressPath
#-------------------------------------------------------------------------------
struct AddressPath{D} <: AbstractComponentPath
    address ::CartesianIndex{D}
    path    ::ComponentPath
end

#-- Constructors
AddressPath{D}() where D = AddressPath{D}(zero(CartesianIndex{D}), ComponentPath())

@doc """
Data type for pointing to `Components` in a component hierarchy where the
top-most data type is a `TopLevel`.

See also: `ComponentPath`.

# Fields
* `address::CartesianIndex{D}` - The address in the `TopLevel` of the first component
    in the path.
* `path::ComponentPath` - The path to the final component after the component
    at `address` has been retrieved.

# Constructors
```jldoctest
julia> AddressPath{2}() == AddressPath{2}(zero(CartesianIndex{2}), ComponentPath())
true
```
""" AddressPath


#-------------------------------------------------------------------------------
# PortPath
#-------------------------------------------------------------------------------
struct PortPath{P <: AbstractComponentPath} <: AbstractPath
    name    ::String
    path    ::P
end

#-- Constructors
PortPath() = PortPath("", ComponentPath())

function PortPath(port::Vector{<:AbstractString})
    name = String(port[end])
    path = ComponentPath(port[1:end-1])
    return PortPath(name, path)
end
function PortPath(port::Vector{<:AbstractString}, address::CartesianIndex)
    name = String(port[end])
    path = AddressPath(address, ComponentPath(port[1:end-1]))
    return PortPath(name, path)
end
PortPath(port::String) = PortPath(split(port, "."))
PortPath(port::String, address::CartesianIndex) = PortPath(split(port, "."), address)

@doc """
    PortPath{P <: AbstractComponentPath} <: AbstractPath

Path to a `Port` type through a component hierarchy. Parameterized by whether
it is means to work on a `TopLevel` or `Component`.

# Fields
* `name::String` - The instance name of the port to retrieve.
* `path::P` - Path to the component containing the desired port.

# Constructors
```jldoctest
julia> PortPath("a.b.c.port")
Port a.b.c.port

julia> PortPath("a.b.c.port", CartesianIndex(1,1))
Port (1, 1).a.b.c.port
```
""" PortPath


#-------------------------------------------------------------------------------
# LinkPath
#-------------------------------------------------------------------------------
struct LinkPath{P <: AbstractComponentPath} <: AbstractPath
    name    ::String
    path    ::P
end

#-- Constructors
LinkPath() = LinkPath("", ComponentPath())

function LinkPath(link::Vector{<:AbstractString})
    linkname = String(link[end])
    path     = ComponentPath(link[1:end-1])
    return LinkPath(linkname, path)
end
function LinkPath(link::Vector{<:AbstractString}, address::CartesianIndex)
    linkname = String(link[end])
    path     = AddressPath(address, ComponentPath(link[1:end-1]))
    return LinkPath(linkname, path)
end

LinkPath(link::String) = LinkPath(split(link, "."))
LinkPath(link::String, address::CartesianIndex) = LinkPath(split(link, "."), address)

@doc """
    LinkPath{P <: AbstractComponentPath} <: AbstractPath

Path to a `Link` type through a component hierarchy. Parameterized by whether
it is means to work on a `TopLevel` or `Component`.

# Fields
* `name::String` - The instance name of the port to retrieve.
* `path::P` - Path to the component containing the desired port.

# Constructors
```jldoctest
julia> LinkPath("a.b.c.link")
Link a.b.c.link

julia> LinkPath("a.b.c.link", CartesianIndex(1,1))
Link (1, 1).a.b.c.link

julia> LinkPath("a.b.c.link", CartesianIndex(0,0))
Link global.a.b.c.link
```
""" LinkPath

#-------------------------------------------------------------------------------
# ALIASES
#-------------------------------------------------------------------------------
const PPC = PortPath{ComponentPath}
const LPC = LinkPath{ComponentPath}

const ComPath = ComponentPath
const AddPath = AddressPath
const AbsPath = AbstractPath

#-------------------------------------------------------------------------------
# PATH METHODS
#-------------------------------------------------------------------------------
getaddress(p::AddressPath)      = p.address
getaddress(p::ComponentPath)    = nothing
getaddress(p::AbstractPath)     = getaddress(p.path)

#-------------------------------------------------------------------------------
constructor(::LinkPath) = LinkPath
constructor(::PortPath) = PortPath

@doc """
    constructor(p::Union{PortPath,LinkPath})

Return a callable constructor functor for the `ComponentPath` parameterized 
version of `p`.
""" constructor

#-------------------------------------------------------------------------------
Base.last(p::ComponentPath) = last(p.path)
Base.last(p::AddressPath)   = length(p.path) > 0 ? last(p.path) : p.address
Base.last(p::PortPath)      = p.name
Base.last(p::LinkPath)      = p.name

@doc """
    last(p::AbstractPath)

Return the last step in path `p`.
""" last

#-------------------------------------------------------------------------------
istop(p::PPC) = length(p.path) == 0
istop(p::PortPath{AddressPath{D}}) where D = false

@doc """
    istop(p::PortPath)

Return `false` if the given port path belongs to a subcomponent of a certain
component.
""" istop

#-------------------------------------------------------------------------------
isgloballink(l::LinkPath) = iszero(l.path.address)
isgloballink(::AbstractPath) = false

@doc """
    isgloballink(p::AbstractPath)

Return `true` if path `p` points to a global routing link.
""" isgloballink

#-------------------------------------------------------------------------------
isglobalport(p::PortPath) = length(p.path) == 1
isglobalport(::AbstractPath) = false

@doc """
    isglobalport(p::AbstractPath)

Return `true` if path `p` points to a global routing port.
""" isglobalport

#-------------------------------------------------------------------------------
Base.length(c::ComponentPath) = length(c.path)
Base.length(p::AddressPath) = (iszero(p.address) ? 0 : 1) + length(p.path)
Base.length(p::AbstractPath) = 1 + length(p.path)

@doc """
    length(p::AbstractPath)

Return the total number of hops in path `p`. Zero addresses do not contribute to
length.
""" length

#-------------------------------------------------------------------------------
prefix(p::AbstractPath) = p.path
prefix(p::ComponentPath) = ComponentPath(p.path[1:end-1])
function prefix(p::AddressPath{D}) where D
    if length(p) > 1
        AddressPath(p.address, prefix(p.path))
    else
        AddressPath{D}()
    end
end

@doc """
    prefix(p::AbstractPath) 

Return a path of all but the last item in `p`. If `p` has only an address,
return an empty address path.
""" prefix

#-------------------------------------------------------------------------------
push(c::ComPath, val::AbstractString) = ComponentPath(vcat(c.path, val))

@doc """
    push(c::ComponentPath, val::String)

Increase the depth of the ComponentPath downwards by appending the string `val`
to the end of the path. Does not modify `c`.
""" push

#-------------------------------------------------------------------------------
pushfirst(a::ComPath, b::AbstractString) = ComponentPath(vcat(b, a.path))
pushfirst(a::ComPath, b::ComPath) = ComponentPath(vcat(b.path, a.path))
pushfirst(a::ComPath, b::CartesianIndex) = AddressPath(b, a)
pushfirst(a::ComPath, b::AddPath) = AddressPath(b.address, pushfirst(a, b.path))
pushfirst(a::PortPath, b) = PortPath(a.name, pushfirst(a.path, b))
pushfirst(a::LinkPath, b) = LinkPath(a.name, pushfirst(a.path, b))

@doc """
    pushfirst(a::AbstractPath, b)

Append `b` to the front of path `a`. Return types are defined when
`typeof(a) == ComponentPath` as follows:

| `typeof(b)`         | Return Type       |
|------------------   | ----------------- |
| `String`            | `ComponentPath`   |
| `ComponentPath`     | `ComponentPath`   |
| `CartesianIndex{D}` | `AddressPath{D}`  |
| `AddressPath{D}`    | `AddressPath{D}`  |

When `a <: PortPath` or `a <: LinkPath`, return type is determined automatically
by calling `pushfirst` on the path portion of `a`.
""" pushfirst

#-------------------------------------------------------------------------------
function Base.split(a::T, n::I = 1) where {T, I <: Integer}
    1 <= n <= length(a) || throw(DomainError())
    r = (constructor(a))(last(a))
    b = prefix(a)
    for i in 2:n
        r = pushfirst(r, last(b))
        b = prefix(b)
    end
    return b,r
end

@doc """
    split(a::T, n::I = 1) where {T <: Union{PortPath,LinkPath}, I <: Integer}

Split the Port/Link path type `a`. Return a tuple of path types `(p,q)` where:

- `a == pushfirst(q,p)`
- `length(q) + length(p) == a`
- `length(q) == n`.

Throws `DomainError` if `n < 1` or `n > length(a)`.
""" split

#-------------------------------------------------------------------------------
##########################
# Undocumented functions #
##########################

# equality - must define for new hash to work correctly.
Base.:(==)(a::ComPath, b::ComPath) = a.path == b.path
Base.:(==)(a::AddPath, b::AddPath) =(a.address == b.address) && (a.path == b.path)
Base.:(==)(a::T, b::T) where T <: AbsPath = (a.name == b.name) && (a.path == b.path)

# hash
@generated function Base.hash(c::T, u::UInt64) where T <: AbstractPath
    ex = [:(u = hash(c.$f,u)) for f in fieldnames(c)]
    return quote $(ex...) end
end

# string and showing
Base.string(c::ComPath)   = join(c.path, ".")
function Base.string(a::AddPath) 
    iszero(a.address) ? (p = "global") : (p = string(a.address.I))
    return join((p,string(a.path)),".")
end
Base.string(p::AbsPath)   = join((string(p.path), p.name), ".")

typestring(p::AbstractComponentPath)    = "Component"
typestring(p::PortPath)                 = "Port"
typestring(p::LinkPath)                 = "Link"

Base.show(io::IO, p::AbsPath)  = print(io, join((typestring(p),string(p)), " "))


################################################################################
#                                  PORT TYPES                                  #
################################################################################

# port s mutable so links can be assigned later
mutable struct Port
    name        ::String
    class       ::String
    link        ::LPC
    metadata    ::Dict{String,Any}
end

#-- Constructor
function Port(name::String, class::String, metadata = emptymeta())
    # validity check
    if !in(class, PORT_CLASSES)
        error("Port Class '$class' is not recognized.")
    end
    link = LinkPath()
    return Port(name, class, link, metadata)
end

const PORT_CLASSES = Set([
    "input",
    "output",
    "bidir",
 ])
const PORT_SOURCES = Set([
    "output",
    "bidir",
 ])
const PORT_SINKS = Set([
    "input",
    "bidir",
 ])

function checkclass(port::Port, dir::Symbol)
    if dir == :source
        return (port.class in PORT_SOURCES)
    elseif dir == :sink
        return (port.class in PORT_SINKS)
    end
    throw(KeyError(dir))
end

############
# Port Doc #
############
@doc """
    mutable struct Port

Port type for modeling input/output ports of a `Component`. Can be one of three
classes: "input", "output", or "bidir".

Ports may be connected to links only at the same level of hierarchy.

# Fields
* `name::String` - The name of this Port.
* `class::String` - The directionality class of the Port.
* `link::LinkPath{ComponentPath}` - Path to the link connected to this port.
    This path is meant to be used to index the component to which the Port
    belongs.
* `metadata::Dict{String,Any}` - Any associated metadata to help with down
    stream processing.

# Constructors

    function Port(name::String, class::String, metadata = Dict{String,Any}())

Return a `Port` with the given `name`, `class`, and `metadata`. Connected link
defaults to an empty `LinkPath`.

Argument `class` must belong to one of "input", "output", or "bidir".
""" Port

################################################################################
#                                  LINK TYPE                                   #
################################################################################
struct Link{P <: AbstractComponentPath}
    name        ::String
    directed    ::Bool
    sources     ::Vector{PortPath{P}}
    sinks       ::Vector{PortPath{P}}
    metadata::Dict{String,Any}
    function Link(name,
                  directed,
                  sources   ::Vector{PortPath{P}},
                  sinks     ::Vector{PortPath{P}},
                  metadata) where P
        return new{P}(name,directed,sources,sinks,Dict{String,Any}(metadata))
    end
end

isaddresslink(::Link{AddressPath{D}}) where {D} = true
isaddresslink(::Link{ComponentPath}) = false

############
# Link Doc #
############
@doc """
    struct Link{P <: AbstractComponentPath}

Link data type for describing which ports are connected. Can have multiple
sources and multiple sinks.

# Fields
* `name::String` - THe name of the link. Can be autogenerated if it is not
    impotant.
* `directed::Bool` - Indicates if the Link is directed or bidirectional.
* `sources::Vector{PortPath{P}}` - Collection of paths to the source ports of
    the link. Meant to be used on the component to which the link belongs.
* `sinks::Vector{PortPath{P}}`  - Collectino of paths to the sink ports of
    the link. Meant to be used on the component to which the link belongs.
* `metadata::Dict{String,Any}` - Any miscellaneous metadata to be used for
    downstream processing.

# Constructors

    link(name::String,
         directed::Bool,
         sources::Vector{PortPath{P}},
         sinks::Vector{PortPath{P}},
         metadata) where P

Returns a new `Link`.
""" Link

@doc """
    isaddresslink(l::Link)

Return `true` if `l` contains an `Address`. Otherwise, return `false`.
""" isaddresslink

################################################################################
#                               COMPONENT TYPES                                #
################################################################################

# Master abstract type from which all component types will subtype
"""
Super type for all components.
All types subtyping from AbstractComponent must have the following fields:

- `children`: Some kind of associative with a keys and values.
"""
abstract type AbstractComponent end

"Return an iterator for the children within a component."
children(c::AbstractComponent) = values(c.children)
"Return an iterator for links within the component."
links(c::AbstractComponent) = values(c.links)

#-------------------------------------------------------------------------------
# Component
#-------------------------------------------------------------------------------
struct Component <: AbstractComponent
    name        ::String
    primitive   ::String
    children    ::Dict{String, Component}
    ports       ::Dict{String, Port}
    links       ::Dict{String, Link{ComponentPath}}
    port_link   ::Dict{PPC,String}
    metadata    ::Dict{String, Any}
end

function Component(
        name;
        primitive   ::String = "",
        metadata = Dict{String, Any}(),
    )
    # Add all component level ports to the ports of this component.
    ports       = Dict{String, Port}()
    links       = Dict{String, Link{ComponentPath}}()
    port_link   = Dict{PPC, String}()
    children    = Dict{String, Component}()
    # Return the newly constructed type.
    return Component(
        name,
        primitive,
        children,
        ports,
        links,
        port_link,
        metadata,
    )
end

@doc """
    Component

Basic building block of architecture models. Can be used to construct
hierarchical models.

Components may be indexed using: `ComponentPath`, `PortPath{ComponentPath}`,
and `LinkPath{ComponentPath}`.

# Constructor

    Component(name, children = Dict{String, Component}(), metadata = Dict{String, Any}())

Return an orphan component with the given name. Can construct with the
given `children` and `metadata`, otherwise those fields will be empty.

# Fields

* `name::String` - The name of this component.
* `primitive::String` - A optional primitive identifier used for potentially
    special treatment. Leave as empty "" if not needed.

    Examples include "mux", which will result in a simpler routing graph for
    mux type components.
* `children::Dict{String,Component}` - Record of the sub components of this
    component. Key corresponds to an instance name, allowing multiple of the
    same component to be instantiated with different instance names.
* `ports::Dict{String,Port}` - Record of all the IO ports for this component.
    Does not include the IO components of children.
* `links::Dict{String,Link{ComponentPath}}` - Record of all links for this
    component. Links can go between component IO ports, and IO ports of
    immediate children of this component.
* `port_link::Dict{PortPath{ComponentPath},String}` - Reverse data structure
    mapping what link is connected to the specified port. A `PortPath` is used
    to disambiguate between ports of the component and ports of the component's
    children.
* `metadata::Dict{String,Any}` - Any extra data that is to be stored with the
    component.
""" Component

#-------------------------------------------------------------------------------
ports(c::Component) = values(c.ports)
ports(c::Component, classes) = Iterators.filter(x -> x.class in classes, values(c.ports))

portnames(c::Component) = collect(keys(c.ports))
function portnames(c::Component, classes)
    return [k for (k,v) in c.ports if v.class in classes]
end

connected_ports(a::AbstractComponent) = keys(a.port_link)

@doc """
    ports(c::Component, [classes])

Return an iterator for all the ports of the given component. Ports of children
are not given. If `classes` are provided, only ports matching the specified
classes will be returned.
""" ports

#-------------------------------------------------------------------------------
# TopLevel
#-------------------------------------------------------------------------------

const _toplevel_constructions = (:add_child, :add_link, :connection_rule)
const _toplevel_analysis = (:walk_children,
                            :connected_components,
                            :search_metadata,
                            :search_metadata!,
                            :check,
                            :build_distance_table,
                            :build_neighbor_table,
                            :connected_link,
                            :connected_ports,
                            :isconnected)




mutable struct TopLevel{A <: AbstractArchitecture,D} <: AbstractComponent
    name        ::String
    children    ::Dict{CartesianIndex{D}, Component}
    links       ::Dict{String, Link{AddressPath{D}}}
    port_link   ::Dict{PortPath{AddressPath{D}}, String}
    metadata    ::Dict{String, Any}

    # --Constructor
    function TopLevel{A,D}(name, metadata = Dict{String,Any}()) where {A,D}
        links       = Dict{String, Link}()
        port_link   = Dict{PortPath{AddressPath{D}}, String}()
        children    = Dict{CartesianIndex{D}, Component}()
        return new{A,D}(name, children, links, port_link, metadata)
    end
end

################################################################################
# Convenience methods.
################################################################################
"""
    addresses(t::TopLevel)

Return an iterator of all addresses with subcomponents of `t`.
"""
addresses(t::TopLevel) = keys(t.children)


#-------------------------------------------------------------------------------
# Various overloadings of the method "getindex"
#-------------------------------------------------------------------------------

function Base.getindex(c::Component, p::ComponentPath)
    for n in p.path
        c = c.children[n]
    end
    return c
end

function Base.getindex(c::Component, p::PortPath)
    # Get the component part
    c = c[p.path]
    # Return the port
    return c.ports[p.name]
end

function Base.getindex(c::Component, p::LinkPath)
    # Get the component part.
    c = c[p.path]
    # Return the link.
    return c.links[p.name]
end

function Base.getindex(tl::TopLevel, p::AddressPath)
    # If the address is all zeros, we mean to get the TopLevel architecture.
    iszero(p.address) && return tl

    # Get the component at the address
    c = tl.children[p.address]
    return c[p.path]
end

function Base.getindex(tl::TopLevel, p::PortPath{T}) where T <: AddressPath
    # component -> port
    c = tl[p.path]
    return c.ports[p.name]
end

function Base.getindex(tl::TopLevel, p::LinkPath{T}) where T <: AddressPath
    # component -> link
    c = tl[p.path]
    return c.links[p.name]
end

"""
    walk_children(c::Component)

Return `Vector{ComponentPath}` enumerating paths to all the children of `c`.
Paths are returned relative to `c`.
"""
function walk_children(c::Component)
    # This is performed as a dfs walk through the sub-component hierarchy of c.
    components = [ComponentPath()]
    queue = [ComponentPath([id]) for id in keys(c.children)]
    while !isempty(queue)
        @compat path = popfirst!(queue)
        push!(components, path)
        # Need to push child the child name to the component path to get the
        # component path relative to c.
        push!(queue, (push(path, id) for id in keys(c[path].children))...)
    end
    return components
end

function connected_components(tl::TopLevel{A,D}) where A where D
    # Construct the associative for the connected components.
    cc = Dict{CartesianIndex{D}, Set{CartesianIndex{D}}}()
    # Iterate through all links - record adjacency information
    for link in links(tl)
        for source_port_path in link.sources, sink_port_path in link.sinks
            src_address = source_port_path.path.address
            snk_address = sink_port_path.path.address
            push_to_dict(cc, src_address, snk_address)
        end
    end
    # Default unseen addresses to an empty set of addresses.
    for address in addresses(tl)
        if !haskey(cc, address)
            cc[address] = Set{CartesianIndex{D}}()
        end
    end
    return cc
end

################################################################################
# METHODS FOR NAVIGATING THE HIERARCHY
################################################################################
function search_metadata(c::AbstractComponent, key, value, f::Function = ==)::Bool
    isempty(key) && return true
    return haskey(c.metadata, key) ? f(value, c.metadata[key]) : false
end

function search_metadata!(c::AbstractComponent, key, value, f::Function = ==)
    # check top component
    search_metadata(c, key, value, f) && return true
    # recursively call search_metadata! on all subcomponents
    for child in values(c.children)
        search_metadata!(child, key, value, f) && return true
    end
    return false
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

function assert_no_intrarouting(c::AbstractComponent)
    passed = true
    for port in values(c.ports)
        # check for default empty link name. If a link is assigned, this will
        # not be the empty string.
        if port.link.name != ""
            passed = false
            @error """
                Component $(c.name) is not expected to have any intra-component
                routing.
                """
            break
        end
    end
    return passed
end

function isfree(c::AbstractComponent, p::PortPath)
    # If this is a top level port - just check the link assigned to the port.
    # If the link name is empty - the port is not yet assigned.
    if istop(p)
        return isempty(c[p].link.name)
    # Otherwise - check the port_link dictionary for the component and see if
    # anything is assigned to this link yet.
    else
        return !haskey(c.port_link, p)
    end
end

################################################################################
# Documentation for TopLevel
################################################################################
@doc """
    TopLevel{A <: AbstractArchitecture, D}

Top level component for an architecture mode. Main difference is between a
`TopLevel` and a `Component` is that children of a `TopLevel` are accessed
via address instead of instance name. A `TopLevel` also does not have any
ports of its own.

Parameter `D` is the dimensionality of the `TopLevel`.

A `TopLevel{A,D}` may be indexed using: 
[`AddressPath{D}`](@ref AddressPath),
[`PortPath{AddressPath{D}}`](@ref PortPath), and 
[`LinkPath{AddressPath{D}}`](@ref LinkPath).

# Constructor
    TopLevel{A,D}(name, metadata = Dict{String,Any}()) where {A <: AbstractArchitecture,D}

Return an empty `TopLevel` with the given name and `metadata`.

# Constructor functions
The following functions may be used to add subcomponents and connect 
subcomponents together:

$(make_ref_list(_toplevel_constructions))

# Analysis routines for TopLevel

$(make_ref_list(_toplevel_analysis))

# Fields
* `name::String` - The name of the TopLevel.
* `children::Dict{CartesinIndex{D},Component}` - Record of the subcomponents accessed
    by address.
* `links::Dict{String,Link{AddressPath{D}}}` - Record of links between ports of
    immediate children.
* `port_link::Dict{PortPath{AddressPath{D}},String}` - Look up giving the `Link`
    in the `links` field connected to the provided port.
* `metadata::Dict{String,Any}()` - Any extra data associated with the
    data structure.
""" TopLevel

@doc """
    connected_components(tl::TopLevel{A,D})

Return `d = Dict{CartesianIndex{D},Set{CartesianIndex{D}}` where key `k` is a 
valid address of `tl` and where `d[k]` is the set of valid addresses of `tl` 
whose components are the destinations of links originating at address `k`.
""" connected_components

@doc """
    search_metadata(c::AbstractComponent, key, value, f::Function = ==)

Search the metadata of field of `c` for `key`. If `c.metadata[key]` does not
exist, return `false`. Otherwise, return `f(value, c.metadata[key])`.

If `isempty(key) == true`, will return `true` regardless of `value` and `f`.
""" search_metadata

@doc """
    search_metadata!(c::AbstractComponent, key, value, f::Function = ==)

Call `search_metadata` on each subcomponent of `c`. Return `true` if function
call return `true` for any subcomponent.
""" search_metadata!

# Assertion Methods
@doc """
    assert_no_children(c::AbstractComponent)

Return `true` if `c` has no children. Otherwise, return `false` and log an
error.
""" assert_no_children

@doc """
    assert_no_intrarouting(c::AbstractComponent)

Return `true` if `c` has not internal links. Otherwise, return `false` and
log an error.
""" assert_no_intrarouting

@doc """
    isfree(c::AbstractComponent, p::PortPath)

Return `true` if portpath `p` is assigned a link in component `c`.
""" isfree
