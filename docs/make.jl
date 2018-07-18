using Documenter, Mapper2

makedocs(
    modules = [Mapper2],
    sitename = "Mapper2.jl",
    format = :html,
    authors = "Mark Hildebrand",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Simulated Annealing Placement" => [
                "man/SA/placement.md", 
                "man/SA/sastruct.md",
                "man/SA/methods.md",
                "man/SA/distance.md",
                "man/SA/move_generators.md",
                "man/SA/map_tables.md",
            ]
        ],
    ]
)
