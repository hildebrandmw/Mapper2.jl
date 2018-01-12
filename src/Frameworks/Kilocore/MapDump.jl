#=
Dumps a JSON data structure recording the basic mapping details for the Project
Manager to read to do with whatever it wants.
=#
function dump_map(m::Map, filename::String)
    # Build a dictionary for json serialize
    jsn = Dict{String,Any}() 
    jsn["nodes"] = sim_create_node_dict(m.mapping)
    jsn["edges"] = sim_create_edge_vec(m.mapping)
    # Open up the file to save
    f = open(filename, "w")
    # Print to JSON with pretty printing.
    print(f, json(jsn, 2))
    close(f)
end

function sim_create_node_dict(m::Mapping)
    node_dict = Dict{String, Any}()
    # Iterate through the dictionary in the mapping nodes
    for (name, nodemap) in m.nodes
        # Create the dictionary for this node.
        dict = Dict{String,Any}()
        dict["address"] = nodemap.path.address.addr
        node_dict[name] = dict
    end
    return node_dict
end

function sim_create_edge_vec(m::Mapping)
    path_vec = Any[]
    for (i, edgemap) in enumerate(m.edges)
        d = Dict{String,Any}()
        path = Any[]
        for p in edgemap.path
            inner_dict = Dict(
                "type" => typestring(p),
                "path" => string(p)
             )
            push!(path, inner_dict)
        end
        d["path"]           = path
        d["edge_number"]    = i
        # Requires "sources" and "sinks" to be in the mapping metadata.
        d["source"] = first(edgemap.metadata["sources"])
        d["sink"]   = first(edgemap.metadata["sinks"])

        @assert length(edgemap.metadata["sources"]) == 1
        @assert length(edgemap.metadata["sinks"]) == 1
        push!(path_vec, d)
    end
    return path_vec
end
