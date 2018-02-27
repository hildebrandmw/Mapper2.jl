# Set working path to Mapper2
# Load Example
using Example

m = (route ∘ place ∘ Example.make_map)();

println((m.mapping.edges[1].path))
println((n.mapping.edges[1].path))

Example.Mapper2.save(m, "test", false)

n = make_map()

Example.Mapper2.load(n, "test", false)

# test
hisn = MapType.global_link_histogram(n)
hism = MapType.global_link_histogram(m)
hisn == hism

# running tests scratch pad
g1 = generate_graphs()

printgraph(g1)
