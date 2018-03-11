function add_port(c::Component, name, class; metadata = emptymeta())
    add_port(c, Port(name, class, metadata))
end

function add_port(c::Component, name, class, number; metadata = emptymeta())
    number < 1 && throw(DomainError())
    for i in 1:number
        port_name = "$name[$(i-1)]"
        # Choose whether to zip or not
        if typeof(metadata) <: Array
            add_port(c, Port(port_name, class, metadata[i]))
        else
            add_port(c, Port(port_name, class, metadata))
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

function add_child(c::AbstractComponent, child::AbstractComponent, name)
    if haskey(c.children, name)
        error("Component $(c.name) already has a child named $name")
    end
    c.children[name] = child
end

function add_child(c::AbstractComponent, child::AbstractComponent, name, number)
    number < 1 && throw(DomainError())
    for i in 0:number-1
        subname = "$name[$i]"
        add_child(c, child, subname)
    end
    return nothing
end

#--------------------------------------------------------------------------------
# Link constructors
#--------------------------------------------------------------------------------

portpath_promote(s::Vector{PortPath{P}}) where P = identity(s)
portpath_promote(s::PortPath)                    = [s]
portpath_promote(s::String)                      = [PortPath(s)]
portpath_promote(s::Vector{String})              = PortPath.(s)


function add_link(c, src_any, dest_any; metadata = emptymeta(), linkname = "")
    
    sources = portpath_promote(src_any)
    sinks = portpath_promote(dest_any)
    # Check port directions
    for src in sources
        if istop(src)
            if !checkclass(c[src], :sink) 
                error("$src is not a valid top-level source port.")
            end
        else
            if !checkclass(c[src], :source)
                error("$src is not a valid source port.")
            end
        end
    end
    for snk in sinks
        if istop(snk)
            if !checkclass(c[snk], :source)
                error("$snk is not a valid top-level sink port.")
            end
        else
            if !checkclass(c[snk], :sink)
                error("$snk is not a valid sink port.")
            end
        end
    end

    # check if port is available for a new link
    for port in chain(sources, sinks)
        if !isfree(c, port)
            error("$port already has a connection.")
        end
    end

    # create link

    # provide default name
    if isempty(linkname)
        linkname = "link[$(length(c.links)+1)]"
    end

    if haskey(c.links, linkname)
        error("Link name: $linkname already exists in component $(c.name)")
    end
    newlink = Link(linkname, true, sources, sinks, metadata)
    # Create a key for this link and add it to the component.
    c.links[linkname] = newlink
    # Create a path for this link
    linkpath = LinkPath(linkname)
    
    # Assign the link to all top level ports.
    for port in chain(sources, sinks)
        if istop(port) 
            c[port].link = linkpath
        end
        # Register the link in the port_link dictionary
        c.port_link[port] = linkname
    end
    return nothing
end


function connection_rule(tl::TopLevel,
                         offset_rules,
                         src_rule,
                         dst_rule;
                         metadata = emptymeta(),
                         valid_addresses = keys(tl.children),
                         invalid_addresses = CartesianIndex[],
                        )
    # Count variable for verification - reports the number of links created.
    count = 0

    for src_address in setdiff(valid_addresses, invalid_addresses)
        # Get the source component
        src = tl.children[src_address]
        # Check if the source component fulfills the requirement.
        src_rule(src) || continue
        # Apply all the offsets to the current address
        for (offset, src_port, dst_port) in offset_rules

            @assert typeof(offset)   <: CartesianIndex
            @assert typeof(src_port) <: String
            @assert typeof(dst_port) <: String

            # Check destination address 
            dst_address = src_address + offset
            haskey(tl.children, dst_address) || continue
            # check destination component
            dst = tl.children[dst_address]
            dst_rule(dst) || continue
            
            # check port existence
            if !(haskey(src.ports, src_port) && haskey(dst.ports, dst_port)) 
                continue
            end

            # Build the name for these ports at the top level. If they are
            # free - connect them.
            src_port_path = PortPath(src_port, src_address)
            dst_port_path = PortPath(dst_port, dst_address)
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
"""
    build_mux(inputs, outputs)

Build a mux with the specified number of inputs and outputs.
"""
function build_mux(inputs, outputs, metadata = emptymeta())
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

Add a child component with the given instance name to a component. If number > 1,
vectorize instantiation names.
""" add_child
