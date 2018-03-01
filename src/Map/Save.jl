#=
Routines for saving and loading placements and routing.
=#
function save(m::Map, filepath)
    # Append .json.gz to the end of the file.
    dir, file = splitdir(filepath)

    ending = ".json"
    file = split(file, ".")[1] * ending

    final_filepath = joinpath(dir, file)
    # Wrap this in one more dictionary
    jsn = Dict{String,Any}()
    jsn["nodes"] = create_node_dict(m.mapping)
    #jsn["edges"] = create_edge_vec(m.mapping)
    # Open up the file to save
    f = open(final_filepath, "w")
    # Print to JSON with pretty printing.
    print(f, json(jsn, 2))
    close(f)
end

# WIP
function load(m::Map, filepath)

    dir, file = splitdir(filepath)
    ending = ".json"
    file = split(file, ".")[1] * ending
    final_filepath = joinpath(dir, file)

    # Open the provided filename and
    f = open(final_filepath, "r")

    jsn = JSON.parse(f)
    close(f)

    read_node_dict(m.mapping, jsn["nodes"])
    #read_edge_vec(m.mapping, jsn["edges"])

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
        dict["address"]     = nodemap.path.address.I
        dict["component"]   = join(nodemap.path.path.path, ".")
        node_dict[name] = dict
    end
    return node_dict
end

function read_node_dict(m::Mapping, d)
    for (name, value) in d
        # Get the nodemap for this node name
        nodemap = m.nodes[name]
        # Create the address data type
        address = CartesianIndex(Tuple(value["address"]))
        component = ComponentPath(value["component"])
        nodemap.path     = AddressPath(address, component)
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
        d["edge_number"]    = i
        push!(path_vec, d)
    end
    return path_vec
end

function read_edge_vec(m::Mapping, path_vec)
    edgemap_vec = Any[]
    for edge in path_vec
        path = Any[]
        for p in edge["path"]
            # split up the string on dots
            split_str = split(p["path"], ".")
            cartesian = first(split_str)

            # Get the coordinates of the cartesian item
            coord_strings = matchall(r"(\d+)(?=[,\)])", cartesian)
            # Build the CartesianIndex
            address = CartesianIndex(parse.(Int64, coord_strings)...)

            if(p["type"] == "Port")
                x = PortPath(split_str[2:end], address)
            elseif(p["type"] == "Link")
                x = LinkPath(split_str[2:end], address)
            end
            push!(path,x) # build the path
        end
        edgemap = EdgeMap(path)
        push!(edgemap_vec, edgemap)
    end
    m.edges = edgemap_vec
    return nothing

end
