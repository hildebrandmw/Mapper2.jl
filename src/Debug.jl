module Debug

export DEBUG, debug_print

const DEBUG     = true

# Colors for printing information.
const colors = Dict(
    # Start of a major operation.
    :start      => :cyan,
    # Start of a minor operation.
    :substart   => :light_cyan,
    # Completion of a major operation.
    :done       => :light_green,
    # Completion of a minor operation.
    :info       => :yellow,
    # More critical info.
    :warning    => 202,
    # Something went wrong.
    :error      => :red,
    # Something was successful.
    :success    => :green,
    # Normal print.
    :none       => :white,
)

debug_print(sym::Symbol, args...) = print_with_color(colors[sym],args...)

end # module Debug
