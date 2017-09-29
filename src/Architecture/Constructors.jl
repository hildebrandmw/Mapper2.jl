#=
Collection of constructor methods to help build the Architecture data type.

IMPORTANT NODES

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
function add_port(c::Component, name, class, number = 1)
    # Pre-allocate array
    ports = Array{Port,1}(number)
    if number == 1
        ports[1] = Port(name, class)
    else
        for i in 1:number
            # Make a new port with this number
            port_name = name * "[" * string(i-1) * "]"
            ports[i] = Port(port_name, class)
        end
    end
    add_port(c, ports...)
    return nothing
end

"""
    add_port(c::Component, port::Port...)

Add ports to a component.
"""
function add_port(c::Component, port::Port...)
    for p in port
        # If the port already exists, throw an error
        if haskey(c.ports, p.name)
            error("Port: ", p.name, " already exists in component ", c.name)
        else
            c.ports[p.name] = p
        end
    end
    return nothing
end

"""
    add_child(c::Component, child::Component, name)

Add a child component with the given instance name to a component. Add all
top level ports of that child.
"""
function add_child(c::AbstractComponent, child::AbstractComponent, name, number = 1)
    if number == 1
        locations = [name]
    else
        locations = [name * "[" * string(i) * "]" for i in 0:number-1]
    end
    for loc in locations
        if haskey(c.children, loc)
            error("Component ", c.name, " already has a child named ", loc)
        else
            c.children[loc] = child
            # Bundle up the location and child as a dictionary to accelerate
            # the adding of ports to the parent module.
            extract_ports!(c, Dict(loc => child))
        end
    end
    return nothing
end

#=
The connect_ports! function is meant for connecting directed links from a source
to a set of destinations. Thus, there is only one source and multiple destinations.

If we need bidirectional support in the future, I'll have to add another function
for connecting together a bunch of bidirectional ports with no notion of
connectedness.

OPTIONS

1. Can incorporate this into the connect_ports! function silenty using a keyword
    or by leaving some array empty.

    This reduces the number of functions but can get potentially confusing and
    might not always be clear if bidirectional semantics are deisred.

2. Make a specific function for connecting bidirectional components. This
    might result in more code, but makes it clear when bidirectional connections
    are desired.

DECISION

For now, go with option 2. Don't really need bidirectional connections for
KiloCore architectures, and making the want of bidirectional components more
explicit is probably better.

MORE THOUGHT TRAIN

May have to add wrappers around these functions to allow more advanced
functionality like mass-connecting ports together.
=#

function connect_ports!(c   ::AbstractComponent,
                        src ::String,
                        dest::String,
                        metadata = Dict{String,Any}())
    connect_ports!(c, src, [dest], metadata)
end

function connect_ports!(c   ::AbstractComponent,
                        src ::String,
                        dest::Array{String,1},
                        metadata = Dict{String,Any}())
    # Make sure that all the ports listed so far do not have a connection
    # already assigned to them
    if length(c.ports[src].neighbors) > 0
        error("Port ", src, " already has a connection.")
    end
    if !(c.ports[src].class ∈ PORT_SOURCES)
        error("Port ", src, " is not a valid source.")
    end
    for port in dest
        if length(c.ports[port].neighbors) > 0
            error("Port ", port, " already has a connection.")
        end
        if !(c.ports[port].class ∈ PORT_SINKS)
            error("Port ", port, " is not a valid source.")
        end
    end
    #=
    Make the connection assignment - One driver to multiple destinations and
    one source for each of the destinations.
    Include the metadata dictionary at each location. It's just a reference
    so this doesn't cost much.
    =#
    c.ports[src].neighbors = dest
    c.ports[src].metadata = metadata
    for port in dest
        c.ports[port].neighbors = [src]
        c.ports[port].metadata = metadata
    end
    return nothing
end

function connection_rule(tl::TopLevel,
                         offsets        ::Array{Address,1},
                         src_key        ::String,
                         src_val,
                         src_function   ::Function,
                         src_ports      ::Array{String,1},
                         dst_key        ::String,
                         dst_val,
                         dst_function   ::Function,
                         dst_ports      ::Array{String,1};
                         metadata = Dict{String,Any}(),
                         valid_addresses = keys(tl.children),
                         invalid_addresses = Address[],
                        )
    # Iterate through each valid address 
    for src_address in setdiff(valid_address, invalid_addresses)
        # Get the source component
        src = tl.children[src_address]
        # Check if the source component fulfills the requirement.
        # If doesn't - abort and go to the next address
        search_metadata!(src, src_key, src_value, src_function) || continue
        # Apply all the offsets to the current address
        for offset in offsets
            dst_address = src_address + offset
            dst = tl.children[dst_address]
            # Check if the destination fulfills the requirements.
            search_metadata!(dst, dst_key, dst_value, dst_function) || continue
            # Now, start iterating through the source and destination ports.
            # if there's a match, connect the ports at the higher level.
            for (src_port, dest_port) in zip(src_ports, dst_ports)
                if !(haskey(src.ports, src_port) && haskey(dst.ports, dst_port)) 
                    continue
                end
                # Build the name for these ports at the top level. If they are
                # free - connect them.
                src_port_name = join((string(src_address), src_port, "."))
                dst_port_name = join((string(dst_address), dst_port, "."))
                if isfree(tl.ports[src_port_name]) && isfree(tl.ports[dst_port_name])
                    connect_ports!(tl, src_port_name, dst_port_name, metadata)
                end
            end
        end
    end
end
