#=
Routines for saving and loading placements and routing.
=#
function save(m::Map, filepath, compress = true)
    # Append .json.gz to the end of the file.
    dir, file = splitdir(filepath)

    ending = compress ? ".json.gz" : ".json"
    file = split(file, ".")[1] * ending

    final_filepath = joinpath(dir, file)
    # Wrap this in one more dictionary
    jsn = Dict{String,Any}()
    jsn["nodes"] = create_node_dict(m.mapping)
    jsn["edges"] = create_edge_vec(m.mapping)
    # Open up the file to save
    if compress
        f = GZip.open(final_filepath, "w")
    else
        f = open(final_filepath, "w")
    end
    # Print to JSON with pretty printing.
    print(f, json(jsn, 2))
    close(f)
end


#=
NOTE: This function is still experimental and is by no means robust. Use
at your own risk.
=#
function load(m::Map, filepath)
    dir, file = splitdir(filepath)
    file = split(file, ".")[1] * ".json.gz"

    final_filepath = joinpath(dir, file)

    # Open the provided filename and
    f = GZip.open(final_filepath, "r")
    jsn = JSON.parse(f)
    close(f)

    read_node_dict(m.mapping, jsn["nodes"])
    return nothing
end

################################################################################
# Helper functions
################################################################################
function create_node_dict(m::Mapping)
    node_dict = Dict{String, Any}()
    # Iterate through the dictionary in the mapping nodes
    for (name, nodemap) in m.nodes
        # Create the dictionary for this node.
        dict = Dict{String,Any}()
        dict["address"]     = nodemap.path.address.addr
        dict["component"]   = join(nodemap.path.path.path, ".")
        dict["metadata"]    = nodemap.metadata
        node_dict[name] = dict
    end
    return node_dict
end

function read_node_dict(m::Mapping, d)
    for (name, value) in d
        # Get the nodemap for this node name
        nodemap = m.nodes[name]
        # Create the address data type
        address = Address(Tuple(value["address"]))
        component = ComponentPath(value["component"])
        metadata::Dict{String,Any} = value["metadata"]

        nodemap.path     = AddressPath(address, component)
        nodemap.metadata = metadata
    end
    return nothing
end

function create_edge_vec(m::Mapping)
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
        d["metadata"]       = edgemap.metadata
        d["edge_number"]    = i
        push!(path_vec, d)
    end
    return path_vec
end

