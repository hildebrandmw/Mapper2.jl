#=
Authors:
    Mark Hildebrand

This defines the basic architecture data types and methods that define an
architecture model. We define a master class "AbstractComponent". From that,
we define concrete "Components".

STRUCTURE

These components will represent functional units of an architecture. For example,
in the case of KiloCore, these could represent the actual processors, routing
muxes, packet routers etc. Components will be hierarchical. Each component
will keep track of its children, and its parent. One constraint is that
all child components must be the same concrete sub-type of AbstractComponent
in order to satisfy Julia's requirement of type stability.

METADATA

Each component will have a meta-data dictionary that will accept string keys
and return the corresponding component. This will allow storage of things
like attributes supplied (as an array of strings), or the number of writes
done by a processor etc.

NOTE: Initially, this will be a
dictionary of type Dict{String, Any}. This is a bit dangerous because of the
type ambiguity, but hopefully this will not have to be referenced that often,
of it it does have to be referenced often will be accelerated externally. If
this causes performance problems in the future, we'll have to revisit it and
see if we can bring performance up.

PRIMITIVE IDENTIFIERS

Further, each component will a string identifier to its primitive type. (If
a primitive type is undeclared, a null string will be used). For example,
primitives like multiplexors will have special methods for building a routing
graph and dumping configuration information post-routing.

COMPONENT NAMES

Each component will also have a name (if no name is supplied, a default will
be supplied). Names of sub-components will be recorded by a parent. Sub
conponents can be accesses using "dot" notation. For example, if the top
level is "arch", it has a sub componend "tile1" which has a sub component
"mux0", the component "mux0" can be accessed from the parent using the
string "arch.tile1.mux0".

PORTS

Components will also have ports which can be connected using links.
Ports will have adjacency lists to record the other ports to which they
are connected. For simplicity, ports may only be connected to other ports
at the same level of hierarchy. Otherwise, it would be way too complicated
to keep track of everything.

Complementary dictionaries in each port will record information about the link,
such as the capacity, cost, and other metrics that people may find relevant
to include with the link.

TOPLEVEL

The top level will be an TopLevel component, which will still behave
like a normal component, but also have the ability to assign addresses
to sub components and will be used as the top level architecture
=#

################################################################################
#                                  PATH TYPES                                  #
################################################################################
#=
These path types will be used to easily access ports, links,  and sub-components
in a given hierarchy.
=#
abstract type AbstractPath end
abstract type AbstractComponentPath <: AbstractPath end

#-------------------------------------------------------------------------------
# Component Path
#-------------------------------------------------------------------------------
"Path to access sub components of a given component"
struct ComponentPath <: AbstractComponentPath
    path::Vector{String}
    ComponentPath(str::Vector{T}) where T <: AbstractString = new(String.(str))
end

#-- Constructors
# Return an empty path. When called on a component, should return the component.
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
"Path to access sub components of a TopLevel"
struct AddressPath{D} <: AbstractComponentPath
    address ::Address{D}
    path    ::ComponentPath
end
#-- Constructors
AddressPath{D}() where D = AddressPath{D}(Address{D}(), ComponentPath())

#-------------------------------------------------------------------------------
# PortPath
#-------------------------------------------------------------------------------
"Path to access Ports in a component"
struct PortPath{P <: AbstractComponentPath} <: AbstractPath
    name    ::String
    path    ::P
end
#-- Constructors
function PortPath(port::AbstractString)
    # Split the path into components based on the "." notation.
    parts = split(port, ".")
    return PortPath(String(parts[end]), ComponentPath(parts[1:end-1]))
end
function PortPath(port::AbstractString, address::Address)
    return PortPath(port, AddressPath(address, ComponentPath()))
end

#-------------------------------------------------------------------------------
# LinkPath
#-------------------------------------------------------------------------------
"Path to access Links in a component"
struct LinkPath{P <: AbstractComponentPath} <: AbstractPath
    name    ::String
    path    ::P
end

#-- Constructors
# Empty Link Path
LinkPath() = LinkPath("", ComponentPath())
LinkPath(link::String) = LinkPath(link, ComponentPath())
LinkPath(link::String, address) = LinkPath(link, AddressPath(address, ComponentPath()))

#-------------------------------------------------------------------------------
# ALIASES
#-------------------------------------------------------------------------------
const PPC = PortPath{ComponentPath}
const LPC = LinkPath{ComponentPath}
const RoutingResourcePath = Union{PortPath,LinkPath}

#-------------------------------------------------------------------------------
# PATH METHODS
#-------------------------------------------------------------------------------
"""
    istop(p::PortPath)

Return `false` if the given port path belongs to a subcomponent of a certain
component.
"""
istop(p::PPC) = length(p.path) == 0
istop(p::PortPath{AddressPath{D}}) where D = false

##########
# LENGTH #
##########
Base.length(c::ComponentPath) = length(c.path)
Base.length(ap::AddressPath)  = 1 + length(ap.path)

############
# EQUALITY #
############
# TODO - unifying this might be nice.
==(a::ComponentPath, b::ComponentPath) = a.path == b.path
==(a::AddressPath,   b::AddressPath)   = (a.address == b.address) && (a.path == b.path)
==(a::T, b::T) where T <: AbstractPath = (a.name == b.name) && (a.path == b.path)

##########
# PREFIX #
##########
prefix(p::AbstractPath) = p.path

##################
# PUSH operators #
##################
#=
NOTE: The "push" and "unshift" operators do not mutate their arguments. Thus,
    the "!" is left off of the function name.
=#
"""
    push(c::ComponentPath, val::String)

Increase the depth of the ComponentPath downwards by appending the string `val`
to the end of the path. Does not modify `c`.
"""
push(c::ComponentPath, val::AbstractString) = ComponentPath(vcat(c.path, val))

#####################
# UNSHIFT operators #
#####################
"""
    unshift(c::ComponentPath, val::String)

Increase the depth of the ComponentPath updwards by appending the string `val`
to the beginning of the path. Does not modify `c`.
"""
unshift(c::ComponentPath, val::AbstractString) = ComponentPath(vcat(val, c.path))

unshift(a::ComponentPath, b::ComponentPath) = ComponentPath(vcat(b.path, a.path))

#=
Here, there is an implicit promotion from a component path to an address
path. This makes sense because adding an address to a component path SHOULD
return an address path.
=#
"""
    unshift(c::ComponentPath, val::Address)

Append an address to the "front" of component path `c`. Returns an AddressPath
with the same dimension as `val`.
"""
unshift(c::ComponentPath, val::Address) = AddressPath(val, c)

unshift(c::ComponentPath, a::AddressPath) = AddressPath(a.address, unshift(c, a.path))

unshift(p::PortPath, val)   = PortPath(p.name, unshift(p.path, val))
unshift(p::PortPath, a::AddressPath) = PortPath(p.name, unshift(p.path, a))
unshift(l::LinkPath, val)   = LinkPath(l.name, unshift(l.path, val))

########
# HASH #
########
#=
NOTE: The default hash for these path type variables seems to be bound to
the address of the type and is thus not stable from run to run.

I've implemented custom hashes here. I used to have a single function that
called "fieldnames" on the type, but that ended up being 50% slower than
writing these custom ones
=#
Base.hash(c::ComponentPath, u::UInt64) = hash(c.path, u)

function Base.hash(c::AddressPath, u::UInt64)
    u = hash(c.address, u)
    return hash(c.path, u)
end

# Fallback for the Port and Link paths.
function Base.hash(c::AbstractPath, u::UInt64)
    u = hash(c.name, u)
    return hash(c.path, u)
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

# Master abstract type - probably not needed.
abstract type AbstractPort end

# Must make the port mutable so we can progressively assign links.
mutable struct Port
    """The name of the port."""
    name        ::String
    """
    The class of the port. Can be "input", "output", "bidir".
    More can be added if needed.
    """
    class       ::String
    """
    Link connected to the port in the component in which it is declared.
    """
    link        ::LPC
    """
    Metadata list - associated with characteristics of the link. Can include
    attributes like "capacity", "network" etc.
    """
    metadata    ::Dict{String,Any}
end

#-- Constructor
"""
    Port(name::String)

Create a new port with the given `name`.
"""
function Port(name::String, class::String, metadata = Dict{String,Any}())
    # Make sure this is a valid port class.
    if !in(class, PORT_CLASSES)
        error("Port Class \'", class, "\' is not recognized.")
    end
    # Create an empty link assignment.
    link = LinkPath()
    # Default
    return Port(
        name,
        class,
        LinkPath(),
        metadata,
)
end

#=
Collect all valid port class strings here.
=#
const PORT_CLASSES = Set([
    "input",
    "output",
    "bidir",
 ])
#=
Valid port classes that can serve as the source of a connection. Do this to
help assure consistency of generated architectures.
=#
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
struct Link{P <: AbstractComponentPath}
    "Name of the link. Will be autogenerated if not provided."
    name    ::String
    "Boolean if link is directed."
    directed::Bool
    sources  ::Vector{PortPath{P}}
    sinks    ::Vector{PortPath{P}}
    "Metadata for the link."
    metadata::Dict{String,Any}
    function Link(name, 
                  directed, 
                  sources::Vector{PortPath{P}}, 
                  sinks::Vector{PortPath{P}}, 
                  metadata) where P
        return new{P}(name,directed,sources,sinks,Dict{String,Any}(metadata))
    end
end

isaddresslink(l::Link{AddressPath{D}}) where {D} = true
isaddresslink(l::Link{ComponentPath}) = false

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
#=
Note - Components are purposely not parameterized because of nesting.
Parameterizing on child type would result in much confusion.
=#
struct Component <: AbstractComponent
    """The declared name of this component"""
    name    ::String
    """Reference to primitive for special operations. Default is \"\"."""
    primitive::String
    """
    Dictionary of all children of this component. String keys will be the
    instance names of the component.
    """
    children::Dict{String, Component}
    ports   ::Dict{String, Port}
    links   ::Dict{String, Link{ComponentPath}}
    "Mapping between ports at this level and links."
    port_link   ::Dict{PPC,String}
    metadata    ::Dict{String, Any}

    #-- Constructor
    """
        Component(name, children = Dict{String, Component}(), metadata = Dict{String, Any}())

    Return an orphan component with the given name. Can construct with the
    given `children` and `metadata`, otherwise those fields will be empty.
    """
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
"""
    ports(c::Component)

Return a iterator for all the ports in the given component. Ports of children
are not given.
"""
ports(c::Component) = values(c.ports)

ports(c::Component, classes) = Iterators.filter(x -> x.class in classes, values(c.ports))

#-------------------------------------------------------------------------------
# TopLevel
#-------------------------------------------------------------------------------

#=
The only difference with the top level is that children are accessed via
addresses instead of names. Since it subtypes from AbstractComponent, it can
share many of the methods defined for normal components.
=#
abstract type AbstractArchitecture end
mutable struct TopLevel{T <: AbstractArchitecture,D} <: AbstractComponent
    """The declared name of this component"""
    name    ::String
    """Reference to primitive for special operations. Default is \"\"."""
    primitive::String
    """
    Dictionary of all children of this component. String keys will be the
    instance names of the component.
    """
    children::Dict{Address{D}, Component}
    """
    Links defined at the top level.
    """
    links   ::Dict{String, Link{AddressPath{D}}}
    port_link::Dict{PortPath{AddressPath{D}}, String}
    metadata::Dict{String, Any}

    # Constructor
    """
        TopLevel(name, dimensions, metadata = Dict{String,Any}())

    Create a top level component with the given name and number of dimensions.
    """
    function TopLevel{T,D}(name, metadata = Dict{String,Any}()) where {T,D}
        # Add all component level ports to the ports of this component.
        primitive   = "toplevel"
        links       = Dict{String, Link}()
        port_link   = Dict{PortPath{AddressPath{D}}, String}()
        children    = Dict{Address{D}, Component}()
        # Return the newly constructed type.
        return new{T,D}(
            name,
            primitive,
            children,
            links,
            port_link,
            metadata,
        )
    end
end

# Accessor Methods for easily getting parameters
architecture(::TopLevel{T,D}) where {T,D} = T
dimension(::TopLevel{T,D}) where {T,D}    = D


################################################################################
# Convenience methods.
################################################################################
"Return an iterator of addresses for the top-level architecture."
addresses(t::TopLevel) = keys(t.children)

pathtype(::Component) = ComponentPath
pathtype(t::TopLevel{A,D}) where {A,D} = AddressPath{D}


#-------------------------------------------------------------------------------
# Various overloadings of the method "getindex"
#-------------------------------------------------------------------------------

"""
    Base.getindex(c::Component, p::ComponentPath)

Return decendent component of `c` pointed to by path `p`.
"""
function Base.getindex(c::Component, p::ComponentPath)
    for n in p.path
        c = c.children[n]
    end
    return c
end

"""
    Base.getindex(c::Component, p::PortPath)

Return port of component `c` pointed to by path `p`.
"""
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

"""
    Base.getindex(tl::TopLevel, p::AddressPath)

Return decendent of the top level pointed by path `p`.
"""
function Base.getindex(tl::TopLevel, p::AddressPath)
    # Get the component at the address
    haskey(tl.children, p.address) || return tl
    c = tl.children[p.address]
    return c[p.path]
end

"""
    Base.getindex(tl::TopLevel, p::PortPath{T})

Return port of the top level pointed to by path `p`.
"""
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

Return all decendents of the current component. Each decendent is in the form
`(component, name)` where `name` is the full instance name of the sub-component.
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
        push!(queue, (push!(path, id) for id in values(c[path].children))...)
    end
    return components
end

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
    # Clean up any unseen addresses
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
function search_metadata(a, key, value, f::Function = ==)::Bool
    # If it doesn't have the key, than just return false. Otherwise, apply
    # the provided function to the value and result.
    return haskey(a.metadata, key) ? f(value, a.metadata[key]) : false
end

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
