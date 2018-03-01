abstract type AbstractArchitecture end
struct BaseArchitecture <: AbstractArchitecture end

"`AbstractPath` top level Abstract Type for Path Types."
abstract type AbstractPath end
"`AbstractComponentPath` specifies this path points to some component."
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

#-------------------------------------------------------------------------------
# AddressPath
#-------------------------------------------------------------------------------
struct AddressPath{D} <: AbstractComponentPath
    address ::CartesianIndex{D}
    path    ::ComponentPath
end

#-- Constructors
AddressPath{D}() where D = AddressPath{D}(zero(CartesianIndex{D}), ComponentPath())


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

constructor(::LinkPath) = LinkPath
constructor(::PortPath) = PortPath

Base.last(p::ComponentPath) = last(p.path)
Base.last(p::AddressPath)   = length(p.path) > 0 ? last(p.path) : p.address
Base.last(p::PortPath)      = p.name
Base.last(p::LinkPath)      = p.name

istop(p::PPC) = length(p.path) == 0
istop(p::PortPath{AddressPath{D}}) where D = false

isgloballink(l::LinkPath) = iszero(l.path.address)
isgloballink(::AbstractPath) = false

isglobalport(p::PortPath) = length(p.path) == 1
isglobalport(::AbstractPath) = false

Base.length(c::ComponentPath) = length(c.path)
Base.length(p::AddressPath) = (iszero(p.address) ? 0 : 1) + length(p.path)
Base.length(p::AbstractPath) = 1 + length(p.path)

prefix(p::AbstractPath) = p.path
prefix(p::ComponentPath) = ComponentPath(p.path[1:end-1])
function prefix(p::AddressPath{D}) where D
    if length(p) > 1
        AddressPath(p.address, prefix(p.path))
    else
        AddressPath{D}()
    end
end

push(c::ComPath, val::AbstractString) = ComponentPath(vcat(c.path, val))

pushfirst(a::ComPath, b::AbstractString) = ComponentPath(vcat(b, a.path))
pushfirst(a::ComPath, b::ComPath) = ComponentPath(vcat(b.path, a.path))
pushfirst(a::ComPath, b::CartesianIndex) = AddressPath(b, a)
pushfirst(a::ComPath, b::AddPath) = AddressPath(b.address, pushfirst(a, b.path))
pushfirst(a::PortPath, b) = PortPath(a.name, pushfirst(a.path, b))
pushfirst(a::LinkPath, b) = LinkPath(a.name, pushfirst(a.path, b))

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

##########################
# Undocumented functions #
##########################

# equality
Base.:(==)(a::ComPath, b::ComPath) = a.path == b.path
Base.:(==)(a::AddPath, b::AddPath) =(a.address == b.address) && (a.path == b.path)
Base.:(==)(a::T, b::T) where T <: AbsPath = (a.name == b.name) && (a.path == b.path)

# hash
@generated function Base.hash(c::T, u::UInt64) where T <: AbstractPath
    ex = [:(u = hash(c.$f,u)) for f in fieldnames(c)]
    return quote $(ex...) end
end

# string and showing
Base.string(c::ComPath) = join(c.path, ".")
Base.string(a::AddPath)   = join((a.address.I, string(a.path)), ".")
Base.string(p::AbsPath)  = join((string(p.path), p.name), ".")
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

################################################################################
#                               COMPONENT TYPES                                #
################################################################################

# Master abstract type from which all component types will subtype
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
ports(c::Component, classes) = Iterators.filter(x -> x.class in classes, values(c.ports))

portnames(c::Component) = keys(c.ports)
function portnames(c::Component, classes)
    return [k for (k,v) in c.ports if v.class in classes]
end

connected_ports(a::AbstractComponent) = keys(a.port_link)

#-------------------------------------------------------------------------------
# TopLevel
#-------------------------------------------------------------------------------

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

function connected_components(tl::TopLevel{A,D}) where A where D
    # Construct the associative for the connected components.
    cc = Dict{CartesianIndex{D}, Set{CartesianIndex{D}}}()
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
            cc[address] = Set{CartesianIndex{D}}()
        end
    end
    return cc
end

################################################################################
# METHODS FOR NAVIGATING THE HIERARCHY
################################################################################
function search_metadata(c::AbstractComponent, key, value, f::Function = ==)::Bool
    # If it doesn't have the key, than just return false. Otherwise, apply
    # the provided function to the value and result.
    isempty(key) && return true
    return haskey(c.metadata, key) ? f(value, c.metadata[key]) : false
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
