# Simulated Annealing

Overview of how to tweak the Simulated Annealing placement algorithm.

# Custom Types
You can influence the behavior of placement by defining your own concrete 
subtypes from the following. If you do not explicitly define your custom 
subtypes, basic types will be used with just the required fields. Thus, if
the functionality you want is achieved with just the basic fields, you do not
need to do anything more.

## AbstractSANode
Data structure representing the nodes in a taskgraph for placement.
```@docs
AbstractSANode
```
### Constructors
```@docs
build_sa_node
```

## AbstractSAEdge
Custom taskgraph edge type for placement.
```@docs
AbstractSAEdge
```
### Constructors
```@docs
build_sa_edge
```

## AbstractAddressData
Used for storing address specific data during placement.
```@docs
AbstractAddressData
```
