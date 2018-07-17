using Documenter, Mapper2

makedocs(
    modules = [Mapper2],
    sitename = "Mapper2.jl",
    format = :html,
    authors = "Mark Hildebrand",
    pages = [
        #"Home" => "index.md",
        "Manual" => [
            "Simulated Annealing" => [
                "man/SA/Placement.md", 
                "man/SA/Struct.md",
                "man/SA/Distance.md",
                "man/SA/MapTables.md",
                "man/SA/MoveGenerators.md",
                "man/SA/ExtendableMethods.md",
            ]
        ],
    ]
)
