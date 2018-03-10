using Documenter, Mapper2

makedocs(
    modules = [Mapper2],
    sitename = "Mapper2.jl",
    format = :html,
    authors = "Mark Hildebrand",
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
                "Architecture Modeling" => Any[
                    "man/architecture.md",
                   ]
            ],
        "Internal Documentation" => Any[
                "lib/internal.md",
                "lib/internals/mappercore.md",
                "lib/internals/placement.md",
                "lib/internals/sa.md",
                "lib/internals/routing.md",
                "lib/internals/helper.md",
            ],
        ]
    )
