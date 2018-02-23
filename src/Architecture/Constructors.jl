#=
Collection of constructor methods to help build the Architecture data type.

IMPORTANT NOTES

When building an architecture, be sure to completely define all portions of
a component at one level of hierarchy before adding instantiating it as a child
in another component. For now, I won't be worrying about maintaining consistency
in the component hierarchy when a child is changed. So make sure everything
is finalized before instantiation.

At some point, I may write a consistency function that makes sure parents
have a consistent view of their children and something has not gone horribly
wrong at some point. This will actually probably be necessary to validate
an architecture after construction as just a form of bug-checking.
=#

"""
    add_port(c::Component, name, class, number)

Add `number` ports with the given `name` and `class`. Ports names will be the
provided suffix with bracket-vector notation.

For example, the function call `add_port(c, "test", "input", 3)` should add
3 `input` ports to component `c` with names: `test[2], test[1], test[0]`.
"""

function add_port(c::Component, name, class, number = 0;
                  metadata = Dict{String, Any}())
    if number == 0
        add_port(c, Port(name, class, metadata))
    else
        for i in 1:number
            # Make a new port with this number
            port_name = "$name[$(i-1)]"
            if typeof(metadata) <: Array
                add_port(c, Port(port_name, class, metadata[i]))
            else
                add_port(c, Port(port_name, class, metadata))
            end 
        end
    end
    return nothing
end

function add_port(c::Component, port::Port)
    # If the port already exists, throw an error
    if haskey(c.ports, port.name)
        error("Port: $(port.name) already exists in component $(c.name)")
    else
        c.ports[port.name] = port
    end
    return nothing
end

"""
    add_child(c::Component, child::Component, name, number = 1)

Add a child component with the given instance name to a component. If number > 1,
vectorize instantiation names.
"""
function add_child(c::AbstractComponent, child::AbstractComponent, name, number = 1)
    if number == 1
        if haskey(c.children, name)
            error("Component $(c.name) already has a child named $name")
        else
            c.children[name] = child
        end
    else
        for i in 0:number-1
            subname = "$name[$i]"
            if haskey(c.children, subname)
                error("Component $(c.name) already has a child named $subname")
            else
                c.children[subname] = child
            end
        end
    end
    return nothing
end

#=
The add_link function is meant for connecting directed links from a source
to a set of destinations. Thus, there is only one source and multiple destinations.

If we need bidirectional support in the future, I'll have to add another function
for connecting together a bunch of bidirectional ports with no notion of
concreteness.

OPTIONS

1. Can incorporate this into the add_link function silently using a keyword
    or by leaving some array empty.

    This reduces the number of functions but can get potentially confusing and
    might not always be clear if bidirectional semantics are desired.

2. Make a specific function for connecting bidirectional components. This
    might result in more code, but makes it clear when bidirectional connections
    are desired.

DECISION

For now, go with option 2. Don't really need bidirectional connections for
KiloCore architectures, and making the want of bidirectional components more
explicit is probably better.
=#
function add_link(c   ::AbstractComponent,
                        src ::String,
                        dest::Array{String,1},
                        metadata = Dict{String,Any}())
    add_link(c, PortPath(src), PortPath.(dest), metadata)
end

function add_link(c   ::AbstractComponent,
                        src ::String,
                        dest::String,
                        metadata = Dict{String,Any}())
    add_link(c, PortPath(src), [PortPath(dest)], metadata)
end

# TODO - clean up this function --- make it more compact.
function add_link(c   ::AbstractComponent,
                        src ::PortPath{P},
                        dest::Array{PortPath{P},1},
                        metadata = Dict{String,Any}(),
                        linkname = "") where P
    
    # Make sure no ports at this level of hierarchy are used.
    # Check the direction of the source
    # TODO: Hoist these into functions.
    if istop(src)
        if !in(c[src].class,PORT_SOURCES)
            error(src, " is not a valid source.")
        end
    else
        if !in(c[src].class,PORT_SINKS)
            error(src, " is not a valid source.")
        end
    end
    for port_path in dest
        if istop(port_path)
            if !in(c[port_path].class,PORT_SINKS)
                error(port_path, " is not a valid sink.")
            end
        else
            if !in(c[port_path].class,PORT_SOURCES)
                error(port_path, " is not a valid sink.")
            end
        end
    end

    port_iterator = chain((src,), dest)
    for port_path in port_iterator
        if !isfree(c, port_path)
            error(port_path, " already has a connection.")
        end
    end

    # Create a link.
    
    # If no link name is given - create a unique one based on the number of
    # links in the component.
    if isempty(linkname)
        linkname = "link[" * string(length(c.links) + 1) * "]"
    end
    # Check if the link name already exists
    if haskey(c.links, linkname)
        error("Link name: ", linkname, " already exists in component ", c.name)
    end
    newlink = Link(linkname, true, [src], dest, metadata)
    # Create a key for this link and add it to the component.
    c.links[linkname] = newlink
    # Create a path for this link
    linkpath = LinkPath(linkname)
    
    # Assign the link to all top level ports.
    for port in port_iterator
        if istop(port) 
            c[port].link = linkpath
        end
        # Register the link in the port_link dictionary
        c.port_link[port] = linkname
    end
    return nothing
end

"""
Structure for recording a connection offset rule for a global connection rule.

Behavior is as follows:

For each `OffsetRule`, the `connection_rule` function will operate on the
Cartesian product of the `offset` vector with the zipped iterator of the
`src_ports` and `dst_ports`. If a connection can be made for a certain offset
and port pair, a connection will be established.
"""
struct OffsetRule
    """
    Offset from source to destination.
    """
    offsets   ::Vector{CartesianIndex}
    """
    Source ports to try for the collection of offsets.
    """
    src_ports::Vector{String}
    """
    Destination ports to try for the collection of offsets.
    """
    dst_ports::Vector{String}
    #=
    It's not always convenient to consciously convert everything to vectors when
    calling the constructor to this function. To get around that, create this
    somewhat ugly constructor that will automatically convert non-vectorized
    function calls into a vector of length 1.
    =#
    function OffsetRule(offsets, src_ports, dst_ports)
        o = typeof(offsets)   <: Vector ? offsets   : [offsets]
        s = typeof(src_ports) <: Vector ? src_ports : [src_ports]
        d = typeof(dst_ports) <: Vector ? dst_ports : [dst_ports]
        return new(o,s,d) 
    end
end

"""
Basically a packed function call to "search_metadata".
Will be called as:

`search_metadata(component, key, val, fn)`
"""
struct PortRule
    key::String
    val::Any
    fn::Function
end

function connection_rule(tl::TopLevel,
                         offset_rules   ::Vector{OffsetRule},
                         src_rule      ::PortRule,
                         dst_rule      ::PortRule;
                         metadata = Dict{String,Any}(),
                         valid_addresses = keys(tl.children),
                         invalid_addresses = CartesianIndex[],
                        )
    # Count variable for verification - reports the number of links created.
    count = 0
    # Unpack the source and destination rule data structure
    src_key = src_rule.key
    src_val = src_rule.val
    src_fn  = src_rule.fn
    dst_key = dst_rule.key
    dst_val = dst_rule.val
    dst_fn  = dst_rule.fn
    #=
    Iteration Order:
    
    1. Source addresses.
    2. Offset rules.
    3. Offsets within each offset rule.
    4. Zipped collection of source and destination ports.

    At each step, check for conditions that will result in ports creation
    failing. These include:

    1. The source address failing the application of the search_metadata! function.
    2. The destination address (sum of source address and offset) not existing
        in the top-level data structure.
    3. Destination address failing the application of the search_metadata! function.
    4. Source or destination ports not existing at the respective addresses.
    5. Either of the source or destination port already has a connection.
    =#
    # Iterate through each valid address 
    for src_address in setdiff(valid_addresses, invalid_addresses)
        # Get the source component
        src = tl.children[src_address]
        # Check if the source component fulfills the requirement.
        # If doesn't - abort and go to the next address
        search_metadata!(src, src_key, src_val, src_fn) || continue
        # Apply all the offsets to the current address
        for offset_rule in offset_rules
            # Unpack OffsetRule struct
            offsets   = offset_rule.offsets
            src_ports = offset_rule.src_ports
            dst_ports = offset_rule.dst_ports
            for offset in offsets
                # Calculate destination address
                dst_address = src_address + offset
                haskey(tl.children, dst_address) || continue
                dst = tl.children[dst_address]
                # Check if the destination fulfills the requirements.
                search_metadata!(dst, dst_key, dst_val, dst_fn) || continue
                # Now, start iterating through the source and destination ports.
                # if there's a match, connect the ports at the higher level.
                for (src_port, dst_port) in zip(src_ports, dst_ports)
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
function build_mux(inputs, outputs)
    name = "mux_" * string(inputs) * "_" * string(outputs)
    component = Component(name, primitive = "mux")
    add_port(component, "in", "input", inputs)
    add_port(component, "out", "output", outputs)
    return component
end
