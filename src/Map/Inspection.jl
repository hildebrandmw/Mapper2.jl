
#=
Inspection methods for the architecture.
=#
function global_links_used(m::Map{A,D}) where {A,D}
    empty_address = Address{D}()
    # Walk through the "mapping" component. 
    global_link_count = 0
    for edge in m.mapping.edges  
        for nodepath in edge.path
            if typeof(nodepath) <: LinkPath
                if nodepath.path.address == empty_address
                    global_link_count += 1
                end
            end
        end
    end
    return global_link_count
end
