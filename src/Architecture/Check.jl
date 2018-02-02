function check(c::AbstractComponent)
    # If there are no children, don't check for unconnected ports.
    if length(c.children) == 0
        return nothing
    end
    # Get all of the ports visible to this level of hierarchy.
    all_ports = get_visible_ports(c)
    # Gather all the registered ports in the "port_link" dictionary
    used_ports = collect(connected_ports(c))

    # This should always be true. If not, one of the constructor functions
    # has gone horribly wrong.
    @assert issubset(used_ports, all_ports)
    # Do a set difference between the two
    unused_ports = setdiff(all_ports, used_ports)
    # Check if there are unused ports and 
    if length(unused_ports) > 0
        debug_print(:warning, 
            "Component $(c.name) has $(length(unused_ports)) unused ports.\n")
        for port in unused_ports
            debug_print(:none, port, "\n")
        end
    end
end

function get_visible_ports(c::Component)
    # Get the ports at this level
    portlist = PortPath.(collect(portnames(c)))
    # Iterate through all children, add their ports to this collection.
    for (name,child) in c.children
        # Get the port strings from the child
        child_ports = unshift.(PortPath.(collect(portnames(child))), name)
        append!(portlist, child_ports)
    end
    return portlist
end

function get_visible_ports(t::TopLevel)
    first = true
    local portlist
    for (address,child) in t.children
        if first
            portlist = PortPath.(collect(portnames(child)), address)
            first = false
        else
            append!(portlist, PortPath.(collect(portnames(child)), address))
        end
    end
    return portlist
end
