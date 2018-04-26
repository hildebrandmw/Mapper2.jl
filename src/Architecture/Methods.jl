function getoffset(a::TopLevel{A,D}) where {A,D} 
    return one(Address{D}) - Address(dim_min(addresses(a)))
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
