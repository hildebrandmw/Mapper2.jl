# Mapper Overview

The goal of the mapper architecture was to allow high speed placement and 
routing while still offering a high degree of flexibility. To achieve this, a
general, "type unstable" central "Map" data structure is used to store 
information regarding:

    - The taskgraph that is currently being mapped.
    - The underlying architecture that the taskgraph is being mapped to.
    - The current state of the mapping such as results of placement or the 
        results of routing.

From this central data structure, specialized data structures for placement and
routing are created to efficiently perform their respective operations. The 
results of these steps are then recorded into the main central structure.

The placement and routing data types themselves are heavily parameterized based
on

    - The Data Type of the architecture being mapped.
    - The dimensionality of the architecture being mapped.
    - The type used to represent taskgraph nodes and edges.
    - and more

Again, the general goal is to allow a high degree of flexibility in algorithms
through parameterization while still yielding high performance.
