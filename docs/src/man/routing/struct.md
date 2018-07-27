# Routing Struct

The Routing Struct is the central datatype for routing, encoding connectivity
information of the ports, links, and other routing resources of the 
architecture. Furthermore, it encodes which links may be used by which channels
in the [`Taskgraph`](@ref) and the valid starting and ending ports for each
channel.

```@docs
Routing.RoutingStruct
```

## API

```@docs
Routing.allroutes
Routing.getroute
Routing.alllinks
Routing.getlink
Routing.start_vertices
Routing.stop_vertices
Routing.getchannel
Routing.getgraph
Routing.iscongested
Routing.clear_route
Routing.setroute
```
