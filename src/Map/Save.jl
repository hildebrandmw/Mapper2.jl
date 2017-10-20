#=
Routines for saving and loading placements and routing.
=#
function save(m::Map, filename::String = "")
    if isempty(filename)
        error("Cannot auto-generate save names yet")
    end
    # Append .json.gz to the end of the file.
    filename = split(filename, ".")[1] * ".json.gz"
    filename = joinpath(PKGDIR, "saved", filename)
    # Wrap this in one more dictionary
    jsn = Dict{String,Any}() 
    jsn["nodes"] = create_node_dict(m.mapping)
    # Open up the file to save
    f = GZip.open(filename, "w")
    print(f, json(jsn, 2))
    close(f)
end

#=
NOTE: This function is still experimental and is by no means robust. Use
at your own risk.
=#
function load(m::Map, filename)
    filename = split(filename, ".")[1] * ".json.gz"
    filename = joinpath(PKGDIR, "saved", filename)

    # Open the provided filename and 
    f = GZip.open(filename, "r")
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
        dict["address"]     = nodemap.address.addr
        dict["component"]   = nodemap.component
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
        component = value["component"]
        metadata::Dict{String,Any} = value["metadata"]
                                         
        nodemap.address = address
        nodemap.component = component
        nodemap.metadata = metadata
    end
    return nothing
end
