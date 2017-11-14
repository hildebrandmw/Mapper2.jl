# Guide to basic Mapper2 functions

# Build the test architecture defined in Mapper2.jl
m = testmap()

#############
# PLACEMENT #
#############

# Build SA Struct
sa = SAStruct(m)
# Place SA Struct.
place(sa,
        move_attempts = 500000,
        warmer = DefaultSAWarm(0.95, 1.1, 0.99),
        cooler = DefaultSACool(0.9),
       )

# Take the results of the SA Struct and save it to the "Map" data structure.
record(m, sa)

###########
# ROUTING #
###########

# Build the routing struct
rs = RoutingStruct(m)
# Build Pathfinder State structure
p = Pathfinder(m, rs)
# Run Pathfinder
route(p, rs)
# Record post-routing information into Map struct
record(m, rs)

#################
# SAVE AND LOAD #
#################

# Default path will save to Mapper2/saved

# Save the Map
save(m, "name-of-save-file")
# Load the map
m = testmap()
load(m, "name-of-save-file")

# Load the placement into the SA Struct.
sa = SAStruct(m)
preplace(m, sa)

plot(sa)
