using Documenter, Mapper2

makedocs(
    modules = [Mapper2],
    sitename = "Mapper2.jl",
    format = :html,
    authors = "Mark Hildebrand",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Architecture Modeling" => [
                "man/architecture/types.md", 
                "man/architecture/components.md",
                "man/architecture/constructors.md",
            ],
            "man/taskgraph.md",
            "man/map.md",
            "man/extensions.md",
            "Simulated Annealing Placement" => [
                "man/SA/placement.md", 
                "man/SA/sastruct.md",
                "man/SA/methods.md",
                "man/SA/types.md",
                "man/SA/distance.md",
                "man/SA/move_generators.md",
                "man/SA/map_tables.md",
            ],
            "Routing" => [
                "man/routing/routing.md",
                "man/routing/struct.md",
                "man/routing/links.md",
                "man/routing/channels.md",
                "man/routing/graph.md",
            ],
            "man/mappergraphs.md",
            "man/helper.md",
            "man/paths.md",
        ],
    ]
)
