function getoffset(a::TopLevel{A,D}) where {A,D}
    return one(Address{D}) - Address(dim_min(addresses(a)))
end

"""
    mappables(a::TopLevel{A,D}, address::Address{D})

Return a `Vector{Path{Component}}` of paths to mappable components at `address`.
"""
function mappables(topleve::TopLevel{A,D}, address::Address{D}) where {A,D}
    return [p for p in walk_children(topleve, address) if ismappable(A, topleve[p])]
end

"""
    check(c::AbstractComponent)

Check a component for ports that are not connected to any link. Only applies
to ports visible to the level of hierarchy of `c`. That is, children of `c` will
not be checked.

Returns a `Vector{PortPath}` of unused ports.
"""
function check(component::AbstractComponent)
    # Gather all visible ports of `c` and all connected visible ports of `c`.
    # The unused ports are just the set diference.
    all_ports  = visible_ports(component)
    used_ports = connected_ports(component)

    unused_ports = setdiff(all_ports, used_ports)

    # Debug printing
    if length(unused_ports) > 0
        @debug begin
            n_unused = length(unused_ports)
            str = "Component $(component.name) has $(n_unused) unused ports. $unused_ports"
        end
    end
    return unused_ports
end

################################################################################
# visible_ports

function visible_ports(component::AbstractComponent)
    # Get ports defined at this level of hierarchy
    paths = portpaths(component)
    # Collect all external ports of children.
    for (name, child) in component.children
        for port in portpaths(child)
            path = catpath(name, port)
            push!(paths, path)
        end
    end
    return paths
end

@doc """
    visible_ports(component::AbstractComponent)

Return `Vector{PortPath}` of the ports of `component` and the ports of the 
children of `component`.
""" visible_ports


################################################################################
# Connectedness methods.
################################################################################

function connectedlink(
        toplevel :: TopLevel, 
        portpath :: Path{Port}, 
        portclass :: PortClass
    )
    # Extract the port type of the top level definition.
    port = toplevel[portpath]

    # If the port direction differs from "class", then we must go up one level
    # in the component hierarchy to get the attached link.
    up_one = port.class == portclass

    split_amount = up_one ? 2 : 1
    cpath, ppath = splitpath(portpath, split_amount)

    # Get the component type and look up the port name in the "portlink" 
    # dictionary to get its connected link.
    component = toplevel[cpath]
    link = component.portlink[ppath]

    # Prefix the name of the component to the link's name to get the full path
    # relative to the toplevel.
    return catpath(cpath, Path{Link}(link.name))
end

function connectedports(
        toplevel :: TopLevel, 
        linkpath :: Path{Link}, 
        class :: PortClass
    )
    link = toplevel[linkpath]
    # Check directionality
    if class == Input
        ports = sources(link)
    elseif class == Output
        ports = dests(link)
    else
        throw(DomainError())
    end

    # Strip the name of the link to just get the prefix.
    linkprefix = striplast(linkpath)
    return catpath.(Ref(linkprefix), ports)

    # If the link is global, its sources and destinations are already full
    # address paths, just return these arrays directly.
    #
    # Otherwise, need to prefix the paths local to the link with the path to
    # the component where the links are defined.

    # isgloballink(linkpath) && (return ports)
    # linkprefix = striplast(linkpath)
    # return [catpath(linkprefix, i) for i in ports]
end

################################################################################
# isconnected
################################################################################


# Default to false
function isconnected(t::TopLevel, a::Path, b::Path)
    @error "Undefined connection"
    return false
end

function isconnected(
        toplevel :: TopLevel, 
        portpath :: Path{Port}, 
        linkpath :: Path{Link}
    )

    # Get the output link connected to the port
    actuallink = connectedlink(toplevel, portpath, Output)
    if linkpath != actuallink
        @error """
            $portpath is not connected to $linkpath.

            It is connected to $actuallink.
            """
        return false
    end
    actualports = connectedports(toplevel, linkpath, Input)
    if portpath ∉ actualports
        @error """
            $linkpath is not connected to $portpath.

            Actual sink ports: $actualports.
            """
    end
    return true
end

function isconnected(
        toplevel :: TopLevel, 
        linkpath :: Path{Link}, 
        portpath :: Path{Port}
    )
    # Get the output link connected to the port
    actuallink = connectedlink(toplevel, portpath, Input)
    if linkpath != actuallink
        @error """
            $portpath is not connected to $linkpath.

            It is connected to $actuallink.
            """
        return false
    end
    actualports = connectedports(toplevel, linkpath, Output)
    if portpath ∉ actualports
        @error """
            $linkpath is not connected to $portpath.

            Actual sink ports: $actualports.
            """
    end
    return true
end

function isconnected(
        toplevel :: TopLevel,
        portpath :: Path{Port},
        #cpath::Path{Component}
        componentpath :: Path{Component}
    )

    # Check if the port is an input of the component by collecting all of the
    # inputs ports of the component and checking for path equality.
    component = toplevel[componentpath]
    component_inputs = catpath.(Ref(componentpath), portpaths(component, (Input,)))

    if portpath ∉ component_inputs
        @error "$portpath is not an input of $componentpath."
        return false
    end
    return true
end

function isconnected(
        toplevel :: TopLevel,
        componentpath :: Path{Component},
        portpath :: Path{Port}
    )

    # Do the same trick as above - get all the output ports of the component
    # by path and check if the given portpath is in them.
    component = toplevel[componentpath]
    component_outputs = catpath.(Ref(componentpath), portpaths(component, (Output,)))

    if portpath ∉ component_outputs
        @error "$portpath is not an input of $componentpath."
        return false
    end
    return true
end

@doc """
    isconnected(toplevel, a::AbstractPath, b::AbstractPath)

Return `true` if architectural component referenced by path `a` is
architecturally connected to that referenced by path `b`.

The order of the arguments is important for directed components. For example,
if `a` references a port that is a source for link `b` in `toplevel`, then

```julia
julia> isconnected(toplevel, a, b)
true

julia> isconnected(toplevel, b, a)
false
```

If one of `a` or `b` is of type `ComponentPath`, then only ports are considered
connected.
""" isconnected
