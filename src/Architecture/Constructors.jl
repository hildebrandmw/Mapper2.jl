function add_port(c::Component, name, class; metadata = emptymeta())
    add_port(c, Port(name, class, metadata))
end

function add_port(c::Component, name, class, number; metadata = emptymeta())
    number < 1 && throw(DomainError())
    for i in 1:number
        port_name = "$name[$(i-1)]"
        # Choose whether to iterate through metadata or not.
        if typeof(metadata) <: Dict
            add_port(c, Port(port_name, class, metadata))
        else
            add_port(c, Port(port_name, class, metadata[i]))
        end
    end
    return nothing
end

function add_port(c::Component, port::Port)
    if haskey(c.ports, port.name)
        error("Port: $(port.name) already exists in component $(c.name)")
    end
    c.ports[port.name] = port
end

function add_child(c::Component, child::Component, name::String, number)
    number < 1 && throw(DomainError())
    for i in 0:number-1
        subname = "$name[$i]"
        add_child(c, child, subname)
    end
    return nothing
end

function add_child(c::Component, child::Component, name::String)
    if haskey(c.children, name)
        error("Component $(c.name) already has a child named $name.")
    end
    c.children[name] = deepcopy(child)
    return nothing
end

function add_child(t        ::TopLevel, 
                   child    ::Component, 
                   address  ::Address, 
                   name     ::String = string(address))
    
    if haskey(t.children, name)
        error("TopLevel $(t.name) already has a child named $name.")
    end
    if haskey(t.address_to_child, address)
        error("TopLevel $(t.name) already has a child assigned to address $address.")
    end

    t.children[name]            = deepcopy(child)
    # Maintain cross references between child names and addresses
    t.child_to_address[name]    = address
    t.address_to_child[address] = name
    return nothing
end

#--------------------------------------------------------------------------------
# Link constructors
#--------------------------------------------------------------------------------

# Convenience functions allowing add_link to be called with
#   - String, vector of string, PortPath, vector of PortPath and have
#   everything just work correctly. Maps all of these to a vector of portpaths.
portpath_promote(s::Vector{Path{Port}}) = identity(s)
portpath_promote(s::Path{Port})         = [s]
portpath_promote(s::String)             = [Path{Port}(s)]
portpath_promote(s::Vector{String})     = [Path{Port}(i) for i in s]

function check_directions(c, sources, sinks) 
    for src in sources
        port = get_relative_port(c, src)
        if !checkclass(port, :source)
            error("$src is not a valid source port for component $(c.name).")
        end
    end
    for snk in sinks
        port = get_relative_port(c, snk)
        if !checkclass(port, :sink)
            error("$snk is not a valid sink port for component $(c.name).")
        end
    end
end

function add_link(
        c :: AbstractComponent, 
        src_any, 
        dest_any, 
        safe = false; 
        metadata = emptymeta(), 
        linkname = "",
    )

    sources = portpath_promote(src_any)
    sinks = portpath_promote(dest_any)
    # Check port directions
    check_directions(c, sources, sinks)

    # check if port is available for a new link
    for port in chain(sources, sinks)
        if !isfree(c, port)
            safe ? (return false) : error("$port already has a connection.")
        end
    end
    # Check if we're trying to connect ports beyond just immedate hierarchy.
    for port in chain(sources, sinks)
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
    if isempty(linkname)
        linkname = "link[$(length(c.links)+1)]"
    end

    if haskey(c.links, linkname)
        if safe
            return false
        else
            error("Link name: $linkname already exists in component $(c.name)")
        end
    end

    newlink = Link(linkname, sources, sinks, metadata)
    # Create a key for this link and add it to the component.
    c.links[linkname] = newlink
    # Assign the link to all top level ports.
    for port in chain(sources, sinks)
        # Register the link in the portlink dictionary
        c.portlink[port] = newlink
    end
    return true
end

tautology(args...) = true

struct Offset
    offset      :: Address
    source_port :: String
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


struct ConnectionRule
    # Vector of offsets to be applied if all below filters pass.
    offsets :: Vector{Offset}

    # Allow filtering of addresses.
    address_filter :: Function
    # Filter source components
    source_filter :: Function
    # Filter destination components
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

function connection_rule(tl::TopLevel, rule :: Vector{Offset}; kwargs...)
    connection_rule(tl, ConnectionRule(rule); kwargs...)
end

function connection_rule(tl::TopLevel, rule::ConnectionRule; metadata = emptymeta())
    # Count variable for verification - reports the number of links created.
    count = 0

    #for src_address in setdiff(valid_addresses, invalid_addresses)
    for src_address in Iterators.filter(rule.address_filter, addresses(tl))
        # Get the source component
        src = getchild(tl, src_address)
        # Check if the source component fulfills the requirement.
        rule.source_filter(src) || continue

        # Apply all the offsets to the current address
        for offset_rule in rule.offsets
            offset = offset_rule.offset
            src_port = offset_rule.source_port
            dst_port = offset_rule.dest_port

            # Check destination address
            dst_address = src_address + offset
            haskey(tl.address_to_child, dst_address) || continue

            # check destination component
            dst = getchild(tl, dst_address)
            rule.dest_filter(dst) || continue

            # check port existence
            if !(haskey(src.ports, src_port) && haskey(dst.ports, dst_port))
                continue
            end

            # Build the name for these ports at the top level. If they are
            # free - connect them.
            src_prefix = tl.address_to_child[src_address]
            dst_prefix = tl.address_to_child[dst_address]
            src_port_path = Path{Port}(src_prefix, src_port)
            dst_port_path = Path{Port}(dst_prefix, dst_port)
            if isfree(tl, src_port_path) && isfree(tl, dst_port_path)
                # level ports container. If not, initialize them.
                add_link(tl, src_port_path, [dst_port_path])
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
    add_port(component, "in", "input", inputs, metadata = metadata)
    add_port(component, "out", "output", outputs, metadata = metadata)
    return component
end

################################################################################
# Documentation
################################################################################

@doc """
    add_port(c::Component, name, class, number; metadata = emptymeta())

Add `number` ports with the given `name` and `class`. Ports names will be the
provided suffix with bracket-vector notation.

For example, the function call `add_port(c, "test", "input", 3)` should add
3 `input` ports to component `c` with names: `test[2], test[1], test[0]`.

If `metadata` is given, it will be assigned to each instantiated port. If
`metadata` is a vector with `length(metadata) == number`, than entries of
`metadata` will be sequentially assigned to each instantiated port.
""" add_port

@doc """
    add_child(c::Component, child::Component, name, number = 1)

Add a child component with the given instance `name` to a component. If
number > 1, vectorize instantiation names. Throw error if `name` is already
used as an instance name for a child.
""" add_child

@doc """
    add_link(c::Component, src, dest; metadata = emptymeta(), linkname = "")

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

@doc """
TODO
""" connection_rule
