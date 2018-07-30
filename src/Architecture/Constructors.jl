################################################################################
# add_port
################################################################################

function add_port(component::Component, name, class; metadata = emptymeta())
    add_port(component, Port(name, class; metadata = metadata))
end

function add_port(component::Component, name, class, number; metadata = emptymeta())
    for i in 0:number-1
        portname = "$name[$(i)]"
        # Choose whether to iterate through metadata or not.
        if typeof(metadata) <: Dict
            port = Port(portname, class, metadata = metadata)
        else
            port = Port(portname, class, metadata = metadata[i+1])
        end
        add_port(component, port)
    end
    return nothing
end

function add_port(component::Component, port::Port)
    if haskey(component.ports, port.name)
        error("Port: $(port.name) already exists in component $(component.name)")
    end
    component.ports[port.name] = port
end

################################################################################
# add_child
################################################################################

function add_child(component::Component, child::Component, name::String, number)
    for i in 0:number-1
        add_child(component, child, "$name[$i]")
    end
    return nothing
end

function add_child(component::Component, child::Component, name::String)
    if haskey(component.children, name)
        error("Component $(c.name) already has a child $name.")
    end
    component.children[name] = deepcopy(child)
    return nothing
end

function add_child(
        toplevel :: TopLevel, 
        child :: Component, 
        address :: Address, 
        name :: String = string(address)
    )
    
    if haskey(toplevel.children, name)
        error("TopLevel $(toplevel.name) already has a child named $name.")
    end
    if haskey(toplevel.address_to_child, address)
        error("""
              TopLevel $(toplevel.name) already has a child assigned to 
              address $address.
              """)
    end

    toplevel.children[name] = deepcopy(child)
    # Maintain cross references between child names and addresses
    toplevel.child_to_address[name] = address
    toplevel.address_to_child[address] = name
    return nothing
end

################################################################################
# add_link
################################################################################

# Convenience functions allowing add_link to be called with
#   - String, vector of string, PortPath, vector of PortPath and have
#   everything just work correctly. Maps all of these to a vector of portpaths.
portpath_promote(s::Vector{Path{Port}}) = identity(s)
portpath_promote(s::Path{Port})         = [s]
portpath_promote(s::String)             = [Path{Port}(s)]
portpath_promote(s::Vector{String})     = [Path{Port}(i) for i in s]

function check_directions(component, sources, sinks) 
    for source in sources
        port = relative_port(component, source)
        if !checkclass(port, Source)
            error("$source is not a valid source port for component $(component.name).")
        end
    end
    for sink in sinks
        port = relative_port(component, sink)
        if !checkclass(port, Sink)
            error("$sink is not a valid sink port for component $(component.name).")
        end
    end
end

function add_link(
        component :: AbstractComponent, 
        src_any, 
        dest_any, 
        safe = false; 
        metadata = emptymeta(), 
        linkname = nothing,
    )

    # Promote the passed sources and destinations to Vector{Path{Port}}
    sources = portpath_promote(src_any)
    sinks = portpath_promote(dest_any)

    # Check port directions
    check_directions(component, sources, sinks)

    # check if port is available for a new link
    for port in Iterators.flatten((sources, sinks))
        if !isfree(component, port)
            safe ? (return false) : error("$port already has a connection.")
        end
    end

    # Check if we're trying to connect ports beyond just immedate hierarchy.
    for port in Iterators.flatten((sources, sinks))
        if length(port) == 0 || length(port) > 2
            error("""
                Links must connect ports defined within a component or to IO
                ports of an immediate child.

                $port violates this rule!.
                """)
        end
    end

    # create link

    # provide default name
    if linkname == nothing
        linkname = "link[$(length(component.links)+1)]"
    end

    if haskey(component.links, linkname)
        if safe
            return false
        else
            error("Link name: $linkname already exists in component $(component.name)")
        end
    end

    newlink = Link(linkname, sources, sinks, metadata)
    # Create a key for this link and add it to the component.
    component.links[linkname] = newlink
    # Assign the link to all top level ports.
    for port in Iterators.flatten((sources, sinks))
        # Register the link in the portlink dictionary
        component.portlink[port] = newlink
    end
    return true
end

tautology(args...) = true

"""
Single rule for connecting ports at the [`TopLevel`](@ref)
"""
struct Offset
    "Offset to add to a source address to reach a destination address"
    offset      :: Address

    "Name of the source port to start a link at."
    source_port :: String

    "Name of the destination port to end a link at."
    dest_port   :: String

    # Do conversions to correct types.
    function Offset(
            offset :: Union{Address,Tuple},
            source_port :: AbstractString, 
            dest_port :: AbstractString
        ) 

        new(
            Address(offset),
            string(source_port),
            string(dest_port),
        )
    end
end

# Allow passing of iterators as a constructor.
Offset(A, B, C) = [Offset(a, b, c) for (a,b,c) in zip(A, B, C)]

"""
Global connection rule for connecting ports at the [`TopLevel`](@ref)
"""
struct ConnectionRule
    """
    `Vector{Offset}` - Collection of [`Offset`] rules to be applied to all
    source addresses that pass the filtering stage.
    """
    offsets :: Vector{Offset}

    "`Function` - Filter for source addresses. Default: `true`"
    address_filter :: Function
    "`Function` - Filter for source components. Default: `true`"
    source_filter :: Function
    "`Function` - Filter for destination components. Default: `true`"
    dest_filter :: Function
end

# Provide KeyWord alternative.
function ConnectionRule(
        offsets; 
        address_filter = tautology,
        source_filter = tautology,
        dest_filter = tautology,
    )

    ConnectionRule(offsets, address_filter, source_filter, dest_filter)
end

Base.iterate(c::ConnectionRule) = (c, nothing)
Base.iterate(c::ConnectionRule, ::Any) = nothing

"""
    connection_rule(toplevel, rule::ConnectionRule; metadata = emptymeta())

Apply `rule::ConnectionRule` to `toplevel`. Source addresses will
first be filtered by `rule.address_filter`. Then, for each filtered
address, the [`Component`] at that address will be passed to 
`rule.source_filter`. 

If the component passes, all elements in `rule.offsets` will be 
applied, assuming the component at destination address passes
`rule.dest_filter`. A new link will then be created provided it is
safe to do so.

Method List
-----------
$(METHODLIST)
""" 
function connection_rule end

function connection_rule(toplevel::TopLevel, rule :: Vector{Offset}; kwargs...)
    connection_rule(toplevel, ConnectionRule(rule); kwargs...)
end

function connection_rule(
        toplevel::TopLevel, 
        rule::ConnectionRule; 
        metadata = emptymeta()
    )
    # Count variable for verification - reports the number of links created.
    count = 0

    #for src_address in setdiff(valid_addresses, invalid_addresses)
    for src_address in Iterators.filter(rule.address_filter, addresses(toplevel))
        # Get the source component
        src = toplevel[src_address]
        # Check if the source component fulfills the requirement.
        rule.source_filter(src) || continue

        # Apply all the offsets to the current address
        for offset_rule in rule.offsets
            offset = offset_rule.offset
            src_port = offset_rule.source_port
            dst_port = offset_rule.dest_port

            # Check destination address
            dst_address = src_address + offset
            isaddress(toplevel, dst_address) || continue

            # check destination component
            dst = toplevel[dst_address]
            rule.dest_filter(dst) || continue

            # check port existence
            if !(haskey(src.ports, src_port) && haskey(dst.ports, dst_port))
                continue
            end

            # Build the name for these ports at the top level. If they are
            # free - connect them.
            src_prefix = getname(toplevel, src_address)
            dst_prefix = getname(toplevel, dst_address)

            src_port_path = Path{Port}(src_prefix, src_port)
            dst_port_path = Path{Port}(dst_prefix, dst_port)
            if isfree(toplevel, src_port_path) && isfree(toplevel, dst_port_path)
                # level ports container. If not, initialize them.
                add_link(toplevel, src_port_path, [dst_port_path])
                count += 1
            end
        end
    end

    @debug "Connections made: $count"
    return nothing
end

##############################
#           MUXES
##############################
function build_mux(inputs, outputs; metadata = emptymeta())
    name = "mux_" * string(inputs) * "_" * string(outputs)
    component = Component(name, primitive = "mux", metadata = metadata)
    add_port(component, "in", Input, inputs, metadata = metadata)
    add_port(component, "out", Output, outputs, metadata = metadata)
    return component
end

################################################################################
# Documentation
################################################################################

@doc """
    add_port(component, name, class, [number]; metadata = emptymeta())

Add `number` ports with the given `name` and `class`. Ports names will be the
provided suffix with bracket-vector notation. If `number` is not given, the
port will be added directly.

For example, the function call `add_port(component, "test", "input", 3)` should 
add 3 `input` ports to component `c` with names: `test[2], test[1], test[0]`.

If `metadata` is given, it will be assigned to each instantiated port. If
`metadata` is a vector with `length(metadata) == number`, than entries of
`metadata` will be sequentially assigned to each instantiated port.
""" add_port

@doc """
    add_child(component, child::Component, name, [number])

Add a deepcopy child component with the given instance `name` to a component. If
`number` is provided, vectorize instantiation names. Throw error if `name` is 
already used as an instance name for a child.
""" add_child

@doc """
    add_link(component, src, dest; metadata = emptymeta(), linkname = "")

Construct a link with the given metadata from the source ports to the 
destination ports. 

Arguments `src` and `dst` may of type `String`, `Vector{String}`, `PortPath`, 
or `Vector{PortPath}`. If keyword argument `linkname` is given, the instantiated
link will be assigned that name. Otherwise, a unique name for the link will be
generated.

An error is raised if:
* Port classes are incorrect for the direction of the link.
* Ports in `src` or `dest` are already assigned to a link.
* A link with the given name already exists in `c`.
""" add_link

@doc """
    build_mux(inputs, outputs; metadata = Dict{String,Any}())

Build a mux with the specified number of inputs and outputs. Inputs and outputs
will be named `in[0], in[1], … , in[inputs-1]` and outputs will be named
`out[0], out[1], … , out[outputs-1]`.

If `metdata` is supplied, the dictionary will be attached to the mux component
itself as well as all ports and links in the mux component.
""" build_mux
