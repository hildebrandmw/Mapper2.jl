using Documenter, Mapper2

makedocs(
    modules = [Mapper2],
    sitename = "Mapper2.jl",
    format = :html,
    authors = "Mark Hildebrand",
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "man/placeholder.md",
            ],
        "Developer" => Any[
            "dev/overview.md",
            "dev/architecture.md",
            "dev/constructor.md",
            "Simulated Annealing" => Any[
                   "dev/sa/struct.md",
                   "dev/sa/algorithm.md",
                ],
            "Pathfinder Routing" => Any[
                    "dev/routing/struct.md", 
                    "dev/routing/algorithm.md",
                ],
            ],
        "Internal Documentation" => "lib/internal.md",
        ]
    )
