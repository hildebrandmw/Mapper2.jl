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
            "man/placement.md",
            "man/sa.md",
            ],
        "Developer" => Any[
            "dev/overview.md",
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
