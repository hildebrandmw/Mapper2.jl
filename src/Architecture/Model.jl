
abstract type AbstractArchitecture end
struct BaseArchitecture <: AbstractArchitecture end

"`AbstractPath` top level Abstract Type for Path Types."
abstract type AbstractPath end
"`AbstractComponentPath` specifies this path points to some component."
abstract type AbstractComponentPath <: AbstractPath end

#-------------------------------------------------------------------------------
# Component Path
#-------------------------------------------------------------------------------
"""
Data type for pointing to `Components` in a component hierarchy where the
top-most data type is a `Component`.

See also: `AddressPath`.

# Fields
* `path::Vector{String}` - Sequential instance ID's specificying which children
    to use to get to the final component.

# Constructors
```julia
julia> ComponentPath() == ComponentPath(String[]) == ComponentPath("")
true

julia> ComponentPath("a.b.c") == ComponentPath(["a","b","c"])
true
```
"""
struct ComponentPath <: AbstractComponentPath
    path::Vector{String}
    # Inner constructor.
    ComponentPath(str::Vector{T}) where T <: AbstractString = new(String.(str))
end

#-- Constructors
ComponentPath() = ComponentPath(String[])

function ComponentPath(str::String)
    if isempty(str)
        return ComponentPath()
    else
        return ComponentPath(split(str, "."))
    end
end

#-------------------------------------------------------------------------------
# AddressPath
#-------------------------------------------------------------------------------
"""
Data type for pointing to `Components` in a component hierarchy where the
top-most data type is a `TopLevel`.

See also: `ComponentPath`.

# Fields
* `address::Address{D}` - The address in the `TopLevel` of the first component
    in the path.
* `path::ComponentPath` - The path to the final component after the component
    at `address` has been retrieved.

# Constructors
```julia
julia> AddressPath{D}() == AddressPath{D}(Address{D}(), ComponentPath())
true
```
"""
struct AddressPath{D} <: AbstractComponentPath
    address ::Address{D}
    path    ::ComponentPath
end
#-- Constructors
AddressPath{D}() where D = AddressPath{D}(Address{D}(), ComponentPath())

#-------------------------------------------------------------------------------
# PortPath
#-------------------------------------------------------------------------------
"""
    PortPath{P <: AbstractComponentPath} <: AbstractPath

Path to a `Port` type through a component hierarchy. Parameterized by whether
it is means to work on a `TopLevel` or `Component`.

# Fields
* `name::String` - The instance name of the port to retrieve.
* `path::P` - Path to the component containing the desired port.

# Constructors
```julia
julia> PortPath("a.b.c.port")
Port a.b.c.port

julia PortPath("a.b.c.port", Address(0,0))
Port Address(0, 0).a.b.c.port
```
"""
struct PortPath{P <: AbstractComponentPath} <: AbstractPath
    name    ::String
    path    ::P
end
#-- Constructors
PortPath() = PortPath("", ComponentPath())
function PortPath(port::AbstractString)
    # Split the path into components based on the "." notation.
    parts = split(port, ".")
    return PortPath(String(parts[end]), ComponentPath(parts[1:end-1]))
end

function PortPath(port::AbstractString, address::Address)
    parts = split(port, ".")
    return PortPath(String(parts[end]),
                    AddressPath(address, ComponentPath(parts[1:end-1])))
end

#-------------------------------------------------------------------------------
# LinkPath
#-------------------------------------------------------------------------------
"""
    LinkPath{P <: AbstractComponentPath} <: AbstractPath

Path to a `Link` type through a component hierarchy. Parameterized by whether
it is means to work on a `TopLevel` or `Component`.

# Fields
* `name::String` - The instance name of the port to retrieve.
* `path::P` - Path to the component containing the desired port.

# Constructors
```julia
julia> LinkPath("a.b.c.link")
Port a.b.c.link

julia PortPath("a.b.c.link", Address(0,0))
Port Address(0, 0).a.b.c.link
```
"""
struct LinkPath{P <: AbstractComponentPath} <: AbstractPath
    name    ::String
    path    ::P
end

#-- Constructors
# Empty Link Path
LinkPath() = LinkPath("", ComponentPath())
function LinkPath(link::String)
    parts = split(link, ".")
    LinkPath(String(parts[end]), ComponentPath(parts[1:end-1]))
end

function LinkPath(link::String, address::Address{D}) where {D}
    parts = split(link, ".")
    LinkPath(String(parts[end]), AddressPath(address, ComponentPath(parts[1:end-1])))
end

#-------------------------------------------------------------------------------
# ALIASES
#-------------------------------------------------------------------------------
const PPC = PortPath{ComponentPath}
const LPC = LinkPath{ComponentPath}
const RoutingResourcePath = Union{PortPath,LinkPath}

#-------------------------------------------------------------------------------
# PATH METHODS
#-------------------------------------------------------------------------------
istop(p::PPC) = length(p.path) == 0
istop(p::PortPath{AddressPath{D}}) where D = false

@doc """
    istop(p::PortPath)

Return `false` if the given port path belongs to a subcomponent of a certain
component.
     """ istop


"""
    isglobal(path::AbstractPath)

Return `true` if the provided path is a global routing link.
"""
isgloballink(path::LinkPath) = isempty(path.path.address)
isgloballink(path::AbstractPath) = false


##########
# LENGTH #
##########
Base.length(c::ComponentPath) = length(c.path)
Base.length(a::AddressPath)  = 1 + length(a.path)

############
# EQUALITY #
############
# TODO - unifying this might be nice.
Base.:(==)(a::ComponentPath, b::ComponentPath) = a.path == b.path
Base.:(==)(a::AddressPath,   b::AddressPath)   =  (a.address == b.address) &&
                                                    (a.path == b.path)

Base.:(==)(a::T, b::T) where T <: AbstractPath =  (a.name == b.name) &&
                                                    (a.path == b.path)

prefix(p::AbstractPath) = p.path
prefix(p::ComponentPath) = p.path[1:end-1]

@doc """
    prefix(p::AbstractPath)

Return all but the last item in a `AbstractPath` type.
""" prefix

##################
# PUSH operators #
##################

"""
    push(c::ComponentPath, val::String)

Increase the depth of the ComponentPath downwards by appending the string `val`
to the end of the path. Does not modify `c`.
"""
push(c::ComponentPath, val::AbstractString) = ComponentPath(vcat(c.path, val))

#####################
# UNSHIFT operators #
#####################
unshift(a::ComponentPath, b::AbstractString)= ComponentPath(vcat(b, a.path))
unshift(a::ComponentPath, b::ComponentPath) = ComponentPath(vcat(b.path, a.path))
unshift(a::ComponentPath, b::Address)       = AddressPath(b, a)
unshift(a::ComponentPath, b::AddressPath)   = AddressPath(b.address, unshift(a, b.path))

unshift(a::PortPath, b)   = PortPath(a.name, unshift(a.path, b))
unshift(a::LinkPath, b)   = LinkPath(a.name, unshift(a.path, b))

@doc """
    unshift(a::AbstractPath, b)

Append `b` to the front of path `a`. Return types are defined when
`typeof(a) == ComponentPath` as follows:

| `typeof(b)`       | Return Type       |
|------------------ | ----------------- |
| `String`          | `ComponentPath`   |
| `ComponentPath`   | `ComponentPath`   |
| `Address{D}`      | `AddressPath{D}`  |
| `AddressPath{D}`  | `AddressPath{D}`  |

When `a <: PortPath` or `a <: LinkPath`, return type is determined automatically
by calling `unshift` on the path portion of `a`.
""" unshift

########
# HASH #
########
@generated function Base.hash(c::T, u::UInt64) where T <: AbstractPath
    ex = [:(u = hash(c.$f,u)) for f in fieldnames(c)]
    return quote $(ex...) end
end

########
# SHOW #
########
Base.string(c::ComponentPath) = join(c.path, ".")
Base.string(a::AddressPath)   = join((a.address, string(a.path)), ".")
Base.string(p::AbstractPath)  = join((string(p.path), p.name), ".")
typestring(p::AbstractComponentPath)    = "Component"
typestring(p::PortPath)                 = "Port"
typestring(p::LinkPath)                 = "Link"

Base.show(io::IO, p::AbstractPath)  = print(io, join((typestring(p),string(p)), " "))


################################################################################
#                                  PORT TYPES                                  #
################################################################################

# Must make the port mutable so we can progressively assign links.
"""
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
"""
mutable struct Port
    name        ::String
    class       ::String
    link        ::LPC
    metadata    ::Dict{String,Any}
end

#-- Constructor
function Port(name::String, class::String, metadata = Dict{String,Any}())
    # Make sure this is a valid port class.
    if !in(class, PORT_CLASSES)
        error("Port Class \'", class, "\' is not recognized.")
    end
    # Create an empty link assignment.
    link = LinkPath()
    return Port(
        name,
        class,
        link,
        metadata,
)
end

const PORT_CLASSES = Set([
    "input",
    "output",
    "bidir",
 ])
const PORT_SOURCES = Set([
    "input",
    "bidir",
 ])
const PORT_SINKS = Set([
    "output",
    "bidir",
 ])


################################################################################
#                                  LINK TYPE                                   #
################################################################################
"""
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
"""
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

#-------------------------------------------------------------------------------
# Methods for abstract components.
#-------------------------------------------------------------------------------
"Return an iterator for the children within a component."
children(c::AbstractComponent) = values(c.children)
"Return an iterator for links within the component."
links(c::AbstractComponent) = values(c.links)

#-------------------------------------------------------------------------------
# Component
#-------------------------------------------------------------------------------
"""
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
"""
struct Component <: AbstractComponent
    name        ::String
    primitive   ::String
    children    ::Dict{String, Component}
    ports       ::Dict{String, Port}
    links       ::Dict{String, Link{ComponentPath}}
    port_link   ::Dict{PPC,String}
    metadata    ::Dict{String, Any}

    #-- Constructor
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
        return new(
            name,
            primitive,
            children,
            ports,
            links,
            port_link,
            metadata,
        )
    end
end
# METHODS

ports(c::Component) = values(c.ports)
portnames(c::Component) = keys(c.ports)
ports(c::Component, classes) = Iterators.filter(x -> x.class in classes, values(c.ports))

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


"""
    TopLevel{A <: AbstractArchitecture, D}

Top level component for an architecture mode. Main difference is between a
`TopLevel` and a `Component` is that children of a `TopLevel` are accessed
via address instead of instance name. A `TopLevel` also does not have any
ports of its own.

Parameter `D` is the dimensionality of the `TopLevel`.

A `TopLevel{A,D}` may be indexed using: `AddressPath{D}`,
`PortPath{AddressPath{D}}`, and `LinkPath{AddressPath{D}}`.

# Constructor
    TopLevel{A,D}(name, metadata = Dict{String,Any}()) where
        {A <: AbstractArchitecture,D}

Return a `TopLevel` with the given name and `metadata`.

# Fields
* `name::String` - The name of the TopLevel.
* `children::Dict{Address{D},Component}` - Record of the subcomponents accessed
    by address.
* `links::Dict{String,Link{AddressPath{D}}}` - Record of links between ports of
    immediate children.
* `port_link::Dict{PortPath{AddressPath{D}},String} - Look up giving the `Link`
    in the `links` field connected to the provided port.
* `metadata::Dict{String,Any}()` - Any extra data associated with the
    data structure.
"""
mutable struct TopLevel{A <: AbstractArchitecture,D} <: AbstractComponent
    name        ::String
    children    ::Dict{Address{D}, Component}
    links       ::Dict{String, Link{AddressPath{D}}}
    port_link   ::Dict{PortPath{AddressPath{D}}, String}
    metadata    ::Dict{String, Any}

    # --Constructor
    function TopLevel{A,D}(name, metadata = Dict{String,Any}()) where {A,D}
        links       = Dict{String, Link}()
        port_link   = Dict{PortPath{AddressPath{D}}, String}()
        children    = Dict{Address{D}, Component}()
        return new{A,D}(
            name,
            children,
            links,
            port_link,
            metadata,
        )
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

pathtype(::Component) = ComponentPath
pathtype(t::TopLevel{A,D}) where {A,D} = AddressPath{D}

@doc """
    pathtype(a::AbstractComponent)

Return the subtype of `AbstractPath` used to get subcomponents from this
component.
""" pathtype


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
    # Get the component at the address
    haskey(tl.children, p.address) || return tl
    c = tl.children[p.address]
    return c[p.path]
end

function Base.getindex(tl::TopLevel, p::PortPath{T}) where T <: AddressPath
    # Get the component and then get the port.
    c = tl[p.path]
    return c.ports[p.name]
end

function Base.getindex(tl::TopLevel, p::LinkPath{T}) where T <: AddressPath
    # Get the component and then the link.
    c = tl[p.path]
    return c.links[p.name]
end


"""
    walk_children(c::Component)

Return `Vector{ComponentPath}` enumerating paths to all the children of `c`.
"""
function walk_children(c::Component)
    # Create an empty component path - which will return the component itself.
    components = [ComponentPath()]
    # Iterate through all children of the component, create a component path
    # for each child.
    queue = [ComponentPath([id]) for id in keys(c.children)]
    # Perform a DFS
    while !isempty(queue)
        # Pull a path off of the queue
        path = shift!(queue)
        # Add the path to the list of components.
        push!(components, path)
        # Walk through all children of the component pointed to by the current
        # path - add all children to the queue
        push!(queue, (push(path, id) for id in keys(c[path].children))...)
    end
    return components
end

"""
    connected_components(tl::TopLevel{A,D})

Return `d = Dict{Address{D},Set{Address{D}}` where key `k` is a valid address of
`tl` and where `d[k]` is the set of valid addresses of `tl` whose components
are the destinations of links originating at address `k`.
"""
function connected_components(tl::TopLevel{A,D}) where A where D
    # Construct the associative for the connected components.
    cc = Dict{Address{D}, Set{Address{D}}}()
    # Iterate through all links - record adjacency information
    for link in links(tl)
        for source_port_path in link.sources, sink_port_path in link.sinks
            # Extract the address from the source port path.
            src_address = source_port_path.path.address
            snk_address = sink_port_path.path.address
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
"""
    search_metadata(c::AbstractComponent, key, value, f::Function = ==)

Search the metadata of field of `c` for `key`. If `c.metadata[key]` does not
exist, return `false`. Otherwise, return `f(value, c.metadata[key])`.
"""
function search_metadata(c::AbstractComponent, key, value, f::Function = ==)::Bool
    # If it doesn't have the key, than just return false. Otherwise, apply
    # the provided function to the value and result.
    isempty(key) && return true
    return haskey(c.metadata, key) ? f(value, c.metadata[key]) : false
end

"""
    search_metadata!(c::AbstractComponent, key, value, f::Function = ==)

Call `search_metadata` on each subcomponent of `c`. Return `true` if function
call return `true` for any subcomponent.
"""
function search_metadata!(c::AbstractComponent, key, value, f::Function = ==)
    # If 'f' evaluates to true here, return true in general.
    search_metadata(c, key, value, f) && return true
    # Otherwise, call recursively call search_metadata! on all subcomponents
    for child in values(c.children)
        search_metadata!(child, key, value, f) && return true
    end
    return false
end

#=
Strategy - get the link and its collection of source or sink ports.
We then augment the source/sink paths with the prefix from the link path
to get the actual path. We then check the actual path with the port path
for a match.
=#
function check_connectivity(architecture,
                            portpath::PortPath,
                            linkpath::LinkPath,
                            dir::Symbol = :source)::Bool
    # Get the link from the architecture.
    link = architecture[linkpath]
    # Collect the ports
    if dir == :source
        portpaths_short = link.sources
    elseif dir == :sink
        portpaths_short = link.sinks
    else
        KeyError(dir)
    end
    # If the link type returned is of AddressPath type, just check to see if
    # the link ports match
    if isaddresslink(link)
        return in(portpath, portpaths_short)
    else
        # Append the prefix of the linkpath to the all the port paths
        link_prefix = prefix(linkpath)
        portpaths = unshift.(portpaths_short, link_prefix)
        # Return true if the port path is in the collection.
        return in(portpath, portpaths)
    end
end

function get_connected_port(architecture,
                            portpaths::Vector{T},
                            linkpath::LinkPath,
                            dir::Symbol = :source) where T <: PortPath
    for portpath in portpaths
        if check_connectivity(architecture, portpath, linkpath, dir)
            return portpath
        end
    end
    error("Connected port path not found.")
end
################################################################################
# ASSERTION METHODS.
################################################################################

"""
    assert_no_children(c::AbstractComponent)

Throw error if component `c` has any children.
"""
function assert_no_children(c::AbstractComponent)
    if length(c.children) != 0
        display(c)
        error("Component ", c.name, " is not expected to have any children.")
    end
    return nothing
end

"""
    assert_no_intrarouting(c::AbstractComponent)

Throw error if component `c` has any intra-component routing.
"""
function assert_no_intrarouting(c::AbstractComponent)
    # Iterate through all ports. Ensure that the neighbor lists for each
    # port is empty.
    for port in values(c.ports)
        if port.link.name != ""
            error("Component ", c.name, " is not expected to have any intra-",
                  "component routing.")
        end
    end
    return nothing
end

# Various convenience methods for ports.
"""
    isfree(p::Port)

Return `true` if port `p` has no neighbors assigned to it yet.
"""
function isfree(c::AbstractComponent, p::PortPath)
    # If this is a top level port - just check the link assigned to the port.
    # If the link name is empty - the port is not yet assigned.
    if istop(p)
        return isempty(c[p].link.name)
    #=
    Otherwise - check the port_link dictionary for the component and see if
    anything is assigned to this link yet.
    =#
    else
        return !haskey(c.port_link, p)
    end
end
