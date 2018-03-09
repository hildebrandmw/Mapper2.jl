################################################################################
# PATHS
################################################################################

# Documentation for path types and their verious methods

#-------------------------------------------------------------------------------
# ComponentPath
#-------------------------------------------------------------------------------
@doc """
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
""" ComponentPath

#-------------------------------------------------------------------------------
# AddressPath
#-------------------------------------------------------------------------------
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
```julia
julia> AddressPath{D}() == AddressPath{D}(zero(CartesianIndex{D}), ComponentPath())
true
```
""" AddressPath

#-------------------------------------------------------------------------------
# PortPath
#-------------------------------------------------------------------------------
@doc """
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

julia PortPath("a.b.c.port", CartesianIndex(0,0))
Port CartesianIndex(0, 0).a.b.c.port
```
""" PortPath

#-------------------------------------------------------------------------------
# LinkPath
#-------------------------------------------------------------------------------
@doc """
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

julia PortPath("a.b.c.link", CartesianIndex(0,0))
Port CartesianIndex(0, 0).a.b.c.link
```
""" LinkPath

#-------------------------------------------------------------------------------
# Methods
#-------------------------------------------------------------------------------

@doc """
    constructor(p::Union{PortPath,LinkPath})

Return a constructor function for the `ComponentPath` parameterized version of `p`.
"""

@doc """
    last(p::AbstractPath)

Return the last step in path `p`.
"""

@doc """
    istop(p::PortPath)

Return `false` if the given port path belongs to a subcomponent of a certain
component.
""" istop

@doc """
    isgloballink(p::AbstractPath)

Return `true` if path `p` points to a global routing link.
""" isgloballink

@doc """
    isglobalport(p::AbstractPath)

Return `true` if path `p` points to a global routing port.
""" isglobalport

@doc """
    length(p::AbstractPath)

Return the total number of hops in path `p`.
""" length

@doc """
    prefix(p::AbstractPath) 

Return a path of all but the last item in `p`. If `p` has only an address,
return an empty address path.
""" prefix

@doc """
    push(c::ComponentPath, val::String)

Increase the depth of the ComponentPath downwards by appending the string `val`
to the end of the path. Does not modify `c`.
""" push

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

@doc """
    split(a::T, n::I = 1) where {T <: Union{PortPath,LinkPath}, I <: Integer}

Split the Port/Link path type `a`. Return a tuple of path types `(p,q)` where:

- `a == pushfirst(q,p)`
- `length(q) + length(p) == a`
- `length(q) == n`.

Throws `DomainError` if `n < 1` or `n > length(a)`.
""" split

################################################################################
# ARCHITECTURE TYPES
################################################################################

#-------------------------------------------------------------------------------
# Port
#-------------------------------------------------------------------------------

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

#-------------------------------------------------------------------------------
# Link
#-------------------------------------------------------------------------------
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

# Methods
@doc """
    isaddresslink(l::Link)

Return `true` if `l` contains an `Address`. Otherwise, return `false`.
""" isaddresslink

#-------------------------------------------------------------------------------
# Components
#-------------------------------------------------------------------------------
@doc """
Super type for all components.
All types subtyping from AbstractComponent must have the following fields:

- `children`: Some kind of associative with a keys and values.
""" AbstractComponent

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

@doc """
    ports(c::Component, [classes])

Return an iterator for all the ports of the given component. Ports of children
are not given. If `classes` are provided, only ports matching the specified
classes will be returned.
""" ports

################################################################################
# TopLevel
################################################################################
@doc """
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
