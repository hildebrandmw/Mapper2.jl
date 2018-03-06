function makejls(filepath)
    dir, file = splitdir(filepath)

    filename = "$(first(split(file, "."))).jls"
    finalpath = joinpath(dir, filename)
    return finalpath
end

function save(m::Map, filepath)
    f = open(makejls(filepath), "w")
    serialize(f, m.mapping)
    close(f)
end

function load(m::Map, filepath)
    f = open(makejls(filepath), "r")
    mapping = deserialize(f)
    close(f)

    # rebind deserialized result
    m.mapping = mapping
end
