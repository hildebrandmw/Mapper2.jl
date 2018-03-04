function check(c::AbstractComponent)
    # If there are no children, don't check for unconnected ports.
    if length(c.children) == 0
        return nothing
    end
    all_ports = get_visible_ports(c)
    used_ports = collect(connected_ports(c))

    # This should always be true. If not, one of the constructor functions
    # has gone horribly wrong.
    @assert issubset(used_ports, all_ports)

    unused_ports = setdiff(all_ports, used_ports)
    # report unused ports.
    if length(unused_ports) > 0
        n_unused = length(unused_ports)
        @info "Component $(c.name) has $(n_unused) unused ports."
        for port in unused_ports
            @debug "Unconnected: $port"
        end
    end
end

function get_visible_ports(c::Component)
    # Get the ports at this level
    portpaths = PortPath.(portnames(c))
    # Iterate through all children, add their ports to this collection.
    for (name,child) in c.children
        full_child_paths = pushfirst.(PortPath.(portnames(child)), name)
        append!(portpaths, full_child_paths)
    end
    return portpaths
end

function get_visible_ports(t::TopLevel{A,D}) where {A,D}
    portpaths = PortPath{AddressPath{D}}[]
    for (address,child) in t.children
        append!(portpaths, PortPath.(portnames(child), address))
    end
    return portpaths
end

################################################################################
# Documentation
################################################################################
@doc """
    check(c::AbstractComponent)

Check all the ports of `c` and the children of `c`. Print a warning if any of
these ports is not connected to a link in `c`.

No warning is generated if `c` has no children.
""" check

@doc """
    get_visible_ports(a::AbstractComponent)

Return a vector of `PortPath` to the ports `a` and the ports of the children
of `a`.
""" get_visible_ports
