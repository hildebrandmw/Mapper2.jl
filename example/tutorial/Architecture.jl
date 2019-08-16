#= 
The general outline of each tile is shown in beautiful ascii "art".

                  Tile
|----------------------------------------|
|                      | ^               |
|   Mappable           | |               |
|   |-----|            | |               |
|   |     |<-\         | |               |
|   |     |\  \        | |               |
|   |-----| \  \       | |               |
|            \  \      | |               |
|             \  \     | |               |
|              \  \    | |  Crossbar     |
|               \  \_|-----|             |
|                \-->|     |------------>|
|------------------->|     |<------------|
|<-------------------|-----|             |
|                      | ^               |
|                      | |               |
|                      | |               |
|                      | |               |
|----------------------------------------|

=#

# First, we have to build a simple Mappable component.
function build_mappable()
    # Start with a bare component
    # Need to indicate that this component is capable of holding a task, so we
    # initialize the metadata dictionary with some data we can use later.
    component = Component("simple", metadata = Dict("mappable" => true))

    # Now all we need to do is add an input and output port.
    add_port(component, "in", Input)
    add_port(component, "out", Output)

    # And we're done, a simple component is build with just a single input and
    # output port.
    return component
end

# We now have to provide Mapper2 with some information regarding which components
# are mappable and which arent.
#
# We check the metadata dictionary for the "mappable" key. If it exists and is
# "true", than the compnent is mappable. Otherwise, it isn't. Simple :)
#
# Note that we MUST make the first argument of this function our locally defined
# subtype of Architecture to correctly extend the "ismappable" method.
Mapper2.ismappable(::Type{TutorialRuleset}, x) = get(x.metadata, "mappable", false)

# Since Crossbars are Mapper primitives, we are now ready to build our tile.
function build_tile()
    # Tiles are Components as well. Components are hierarchical in that 
    # component may have subcomponent, each of which may have further more sub-
    # components etc.
    tile = Component("tile")

    # Declare the 4 input and 4 output ports
    for direction in ("north", "east", "south", "west")
        add_port(tile, "$(direction)_in", Input)
        add_port(tile, "$(direction)_out", Output)
    end

    # Instantiate the mappable primitive and add it as a subcomponent of the tile.
    # The instance name of the mappable component is "mappable"
    add_child(tile, build_mappable(), "mappable")

    # Next, we want to add the crossbar, which is unfortunately called "mux" in
    # the Mapper. Referencing the picture above, we want 5 inputs and 5 outputs.
    #
    # Note that the instance name of this component is "mux".
    add_child(tile, build_mux(5, 5), "mux")

    # Finally, start connecting ports together.
    # We first connect the "mappable" to "mux". Note that port names are 
    # hierarchical based on instance names and port names.
    add_link(tile, "mappable.out", "mux.in[4]")
    add_link(tile, "mux.out[4]", "mappable.in")

    # Next, we connect the crossbar to the input and output ports of the tile.
    add_link(tile, "mux.out[0]", "north_out")
    add_link(tile, "mux.out[1]", "east_out")
    add_link(tile, "mux.out[2]", "south_out")
    add_link(tile, "mux.out[3]", "west_out")

    add_link(tile, "north_in", "mux.in[0]")
    add_link(tile, "east_in",  "mux.in[1]")
    add_link(tile, "south_in", "mux.in[2]")
    add_link(tile, "west_in",  "mux.in[3]")

    # And that's it!
    return tile
end

# Now that we've defined how to build a tile, we have to define how to build
# an architecture. This example will generate a 2D rectangular, rectilinear 
# architecture with parameterized width and height.
function build_arch(width, height)
    # Initialize an empty TopLevel.
    # The parameter for the TopLevel is the dimensionality of the 
    # architecture, which is 2.
    arch = TopLevel{2}("architecture")

    # Build a tile. We'll use this same tile at all locations of the grid.
    tile = build_tile()

    # Iterate over all rows and columns needed to achieve this height and width.
    # Build an address for this row and column and instantiate the tile.
    #
    # Since we don't provide the "add_child" method with a name for the 
    # component, it will automatically generate one.
    for (row, col) in Iterators.product(1:width, 1:height)
        address = Address(row, col)
        add_child(arch, tile, address)
    end

    # Finally, we have to connect all these tiles together.
    # Simply define the Address offsets and source -> destination port pairs.
    offsets = [
        Offset((-1, 0), "north_out", "south_in"),
        Offset(( 1, 0), "south_out", "north_in"),
        Offset(( 0, 1), "east_out",  "west_in" ),
        Offset(( 0,-1), "west_out",  "east_in" ),
    ]
    
    connection_rule(arch, offsets)

    # And we're done!.
    return arch
end

# We don't want to have to worry about congestion in the final mapping, so
# lets set the capacity of all our routing resources to 100.
Mapper2.getcapacity(::Type{TutorialRuleset}, x) = 100
