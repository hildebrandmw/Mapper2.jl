var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#Mapper2-1",
    "page": "Home",
    "title": "Mapper2",
    "category": "section",
    "text": "Mapper2 is a general place-and-route framework. It allows for heterogenous  mapping to arbitrary-dimensional architectural models. Features of this package include:Types and constructors for heterogenous many-core processors.\nUser-defined semantics for placement and routing with generic fallbacks,    allowing the user to customize these algorithms for their architecture.\nExtensibility in algorithms for implementing new placement and routing    techniques."
},

{
    "location": "index.html#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "This package may be installed from the Julia REPL using the command:Pkg.clone(\"https://github.com/hildebrandmw/Mapper2.jl\")"
},

{
    "location": "index.html#Mapper2.MapperCore.RuleSet",
    "page": "Home",
    "title": "Mapper2.MapperCore.RuleSet",
    "category": "type",
    "text": "abstract type RuleSet\n\nFields\n\nDocumentation\n\nRuleSet\n\nAbstract supertype for controlling dispatch to specialized functions for architecture interpretation. Create a custom concrete subtype of this if you want to use custom methods during placement or routing.\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "index.html#RuleSet-Types-1",
    "page": "Home",
    "title": "RuleSet Types",
    "category": "section",
    "text": "Much of the behavior of this module can be affected by defining a custom subtype of RuleSet and extending various methods.MapperCore.RuleSet"
},

{
    "location": "man/architecture/types.html#",
    "page": "Core Types",
    "title": "Core Types",
    "category": "page",
    "text": ""
},

{
    "location": "man/architecture/types.html#Core-Types-1",
    "page": "Core Types",
    "title": "Core Types",
    "category": "section",
    "text": ""
},

{
    "location": "man/architecture/types.html#Mapper2.MapperCore.Port",
    "page": "Core Types",
    "title": "Mapper2.MapperCore.Port",
    "category": "type",
    "text": "Port type for modeling input/output ports of a Component.\n\nAPI\n\ncheckclass\ninvert\n\n\n\n\n\n"
},

{
    "location": "man/architecture/types.html#Port-1",
    "page": "Core Types",
    "title": "Port",
    "category": "section",
    "text": "MapperCore.Port"
},

{
    "location": "man/architecture/types.html#Mapper2.MapperCore.checkclass",
    "page": "Core Types",
    "title": "Mapper2.MapperCore.checkclass",
    "category": "function",
    "text": "checkclass(port, direction)\n\n\nReturn true if port is the correct class for the given Direction\n\n\n\n\n\n"
},

{
    "location": "man/architecture/types.html#Mapper2.MapperCore.invert",
    "page": "Core Types",
    "title": "Mapper2.MapperCore.invert",
    "category": "function",
    "text": "invert(port)\n\n\nReturn a version of port with the class inverted.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/types.html#Mapper2.MapperCore.PortClass",
    "page": "Core Types",
    "title": "Mapper2.MapperCore.PortClass",
    "category": "type",
    "text": "Classification of port types.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/types.html#Mapper2.MapperCore.Direction",
    "page": "Core Types",
    "title": "Mapper2.MapperCore.Direction",
    "category": "type",
    "text": "Enum indicating a direction. Values: Source, Sink.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/types.html#API-1",
    "page": "Core Types",
    "title": "API",
    "category": "section",
    "text": "MapperCore.checkclass\nMapperCore.invert\nMapperCore.PortClass\nMapperCore.Direction"
},

{
    "location": "man/architecture/types.html#Mapper2.MapperCore.Link",
    "page": "Core Types",
    "title": "Mapper2.MapperCore.Link",
    "category": "type",
    "text": "struct Link{P <: AbstractComponentPath}\n\nLink data type for describing which ports are connected. Can have multiple sources and multiple sinks.\n\nAPI\n\nsources\ndests\n\n\n\n\n\n"
},

{
    "location": "man/architecture/types.html#Link-1",
    "page": "Core Types",
    "title": "Link",
    "category": "section",
    "text": "MapperCore.Link"
},

{
    "location": "man/architecture/types.html#Mapper2.MapperCore.sources",
    "page": "Core Types",
    "title": "Mapper2.MapperCore.sources",
    "category": "function",
    "text": "sources(link)\n\n\nReturn Vector{Path{Port}} of sources for link.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/types.html#Mapper2.MapperCore.dests",
    "page": "Core Types",
    "title": "Mapper2.MapperCore.dests",
    "category": "function",
    "text": "dests(link)\n\n\nReturn Vector{Path{Port}} of destinations for link.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/types.html#API-2",
    "page": "Core Types",
    "title": "API",
    "category": "section",
    "text": "MapperCore.sources\nMapperCore.dests"
},

{
    "location": "man/architecture/components.html#",
    "page": "AbstractComponent",
    "title": "AbstractComponent",
    "category": "page",
    "text": ""
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.getaddress",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.getaddress",
    "category": "function",
    "text": "getaddress(item)\n\nSingle argument version: Return an address encapsulated in item.\n\ngetaddress(item, index)\n\nGet an address from item referenced by index.\n\nMethod List\n\ngetaddress(toplevel, path)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Architecture.jl:324.\n\ngetaddress(toplevel, str)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Architecture.jl:325.\n\ngetaddress(map, nodename)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Map/Map.jl:87.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.check",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.check",
    "category": "function",
    "text": "check(c::AbstractComponent)\n\nCheck a component for ports that are not connected to any link. Only applies to ports visible to the level of hierarchy of c. That is, children of c will not be checked.\n\nReturns a Vector{PortPath} of unused ports.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.children",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.children",
    "category": "function",
    "text": "Return an iterator for the children within a component.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Base.getindex",
    "page": "AbstractComponent",
    "title": "Base.getindex",
    "category": "function",
    "text": "getindex(component, path::Path{T})::T where T <: Union{Port,Link,Component}\n\nReturn the architecture type referenced by path. Error horribly if path does not exist.\n\ngetindex(toplevel, address)::Component\n\nReturn the top level component of toplevel at address.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.links",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.links",
    "category": "function",
    "text": "Return an iterator for links within the component.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.walk_children",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.walk_children",
    "category": "function",
    "text": "walk_children(component::AbstractComponent, [address]) :: Vector{Path{Component}}\n\nReturn relative paths to all the children of component. If address is given return relative paths to all components at address.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.search_metadata",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.search_metadata",
    "category": "function",
    "text": "search_metadata(c::AbstractComponent, key, value, f::Function = ==)\n\nSearch the metadata of field of c for key. If c.metadata[key] does not exist, return false. Otherwise, return f(value, c.metadata[key]).\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.search_metadata!",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.search_metadata!",
    "category": "function",
    "text": "search_metadata!(c::AbstractComponent, key, value, f::Function = ==)\n\nCall search_metadata on each subcomponent of c. Return true if function call return true for any subcomponent.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.visible_ports",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.visible_ports",
    "category": "function",
    "text": "visible_ports(component::AbstractComponent)\n\nReturn Vector{PortPath} of the ports of component and the ports of the  children of component.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#AbstractComponent-1",
    "page": "AbstractComponent",
    "title": "AbstractComponent",
    "category": "section",
    "text": "Architecture blocks are modelled as a subtype of AbstractComponent. There are two main subtypes: Component, which represents all blocks that are not at the top level of an architecture model, and TopLevel. There is only TopLevel per architecture model.MapperCore.getaddress\nMapperCore.check\nMapperCore.children\nMapperCore.getindex\nMapperCore.links\nMapperCore.walk_children\nMapperCore.search_metadata\nMapperCore.search_metadata!\nMapperCore.visible_ports"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.Component",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.Component",
    "category": "type",
    "text": "struct Component <: AbstractComponent\n\nFields\n\nname\nprimitive\nchildren\nSub-components of this component. Indexed by instance name.\nports\nPorts instantiated directly by this component. Indexed by instance name.\nlinks\nLinks instantiated directly by this component. Indexed by instance name.\nportlink\nRecord of the Link (by name) attached to a Port, keyed by Path{Port}. Length of each Path{Port} must be 1 or 2, to reference ports either instantiated by this component directly, or by one of this component\'s immediate children.j\n\nmetadata\nDict{String,Any} for holding any extra data needed by the user.\n\nDocumentation\n\nBasic building block of architecture models. Can be used to construct hierarchical models.\n\nMethod List\n\nComponent(name, primitive, children, ports, links, portlink, metadata)\nComponent(name, primitive, children, ports, links, portlink, metadata)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Architecture.jl:126.\n\nComponent(name; primitive, metadata)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Architecture.jl:154.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.ports",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.ports",
    "category": "function",
    "text": "ports(component, [classes])\n\nReturn an iterator for all the ports of the given component. Ports of children are not given. If classes are provided, only ports matching the specified classes will be returned.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.portpaths",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.portpaths",
    "category": "function",
    "text": "portpaths(component, [classes])::Vector{Path{Port}}\n\nReturn Paths to all ports immediately instantiated in component.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Component-1",
    "page": "AbstractComponent",
    "title": "Component",
    "category": "section",
    "text": "MapperCore.ComponentThe following methods apply only to concrete [Component] types:MapperCore.ports\nMapperCore.portpaths"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.TopLevel",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.TopLevel",
    "category": "type",
    "text": "struct TopLevel{D} <: AbstractComponent\n\nFields\n\nname\nchildren\nDirect children of the TopLevel, indexed by instance name.\nchild_to_address\nTranslation from child instance name to the Address that child occupies.\naddress_to_child\nTranslation from Address to the Component at that address.\nlinks\nLinks instantiated directly by the TopLevel.\nportlink\nRecord of which Links are attached to which Ports. Indexed by `Path{Port}.\nmetadata\n\nDocumentation\n\nTop level component for an architecture mode. Main difference is between a TopLevel and a Component is that children of a TopLevel are accessed via address instead of instance name. A TopLevel also does not have any ports of its own.\n\nParameter D is the dimensionality of the TopLevel.\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.addresses",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.addresses",
    "category": "function",
    "text": "addresses(toplevel)\n\n\nReturn an iterator of all addresses with subcomponents in toplevel.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.hasaddress",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.hasaddress",
    "category": "function",
    "text": "hasaddress(toplevel, path)\n\nReturn true if the item referenced by path has an Address.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.isaddress",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.isaddress",
    "category": "function",
    "text": "isaddress(toplevel, address)\n\nReturn true if address exists in toplevel.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.connected_components",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.connected_components",
    "category": "function",
    "text": "connected_components(toplevel::TopLevel{A,D})::Dict{Address{D}, Set{Address{D}}\n\nReturn d where key k is a valid address of tl and where d[k] is the set of valid addresses of tl whose components are the destinations of links originating at address k.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.mappables",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.mappables",
    "category": "function",
    "text": "mappables(a::TopLevel{D}, address::Address{D})\n\nReturn a Vector{Path{Component}} of paths to mappable components at address.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#Mapper2.MapperCore.isconnected",
    "page": "AbstractComponent",
    "title": "Mapper2.MapperCore.isconnected",
    "category": "function",
    "text": "isconnected(toplevel, a::AbstractPath, b::AbstractPath)\n\nReturn true if architectural component referenced by path a is architecturally connected to that referenced by path b.\n\nThe order of the arguments is important for directed components. For example, if a references a port that is a source for link b in toplevel, then\n\njulia> isconnected(toplevel, a, b)\ntrue\n\njulia> isconnected(toplevel, b, a)\nfalse\n\nIf one of a or b is of type ComponentPath, then only ports are considered connected.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/components.html#TopLevel-1",
    "page": "AbstractComponent",
    "title": "TopLevel",
    "category": "section",
    "text": "MapperCore.TopLevelThe following methods apply only TopLevel types:MapperCore.addresses\nMapperCore.hasaddress\nMapperCore.isaddress\nMapperCore.connected_components\nMapperCore.mappables\nMapperCore.isconnected"
},

{
    "location": "man/architecture/constructors.html#",
    "page": "Architecture Constructors",
    "title": "Architecture Constructors",
    "category": "page",
    "text": ""
},

{
    "location": "man/architecture/constructors.html#Mapper2.MapperCore.add_port",
    "page": "Architecture Constructors",
    "title": "Mapper2.MapperCore.add_port",
    "category": "function",
    "text": "add_port(component, name, class, [number]; metadata = emptymeta())\n\nAdd number ports with the given name and class. Ports names will be the provided suffix with bracket-vector notation. If number is not given, the port will be added directly.\n\nFor example, the function call add_port(component, \"test\", \"input\", 3) should  add 3 input ports to component c with names: test[2], test[1], test[0].\n\nIf metadata is given, it will be assigned to each instantiated port. If metadata is a vector with length(metadata) == number, than entries of metadata will be sequentially assigned to each instantiated port.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/constructors.html#Mapper2.MapperCore.add_child",
    "page": "Architecture Constructors",
    "title": "Mapper2.MapperCore.add_child",
    "category": "function",
    "text": "add_child(component, child::Component, name, [number])\n\nAdd a deepcopy child component with the given instance name to a component. If number is provided, vectorize instantiation names. Throw error if name is  already used as an instance name for a child.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/constructors.html#Mapper2.MapperCore.add_link",
    "page": "Architecture Constructors",
    "title": "Mapper2.MapperCore.add_link",
    "category": "function",
    "text": "add_link(component, src, dest; metadata = emptymeta(), linkname = \"\")\n\nConstruct a link with the given metadata from the source ports to the  destination ports. \n\nArguments src and dst may of type String, Vector{String}, PortPath,  or Vector{PortPath}. If keyword argument linkname is given, the instantiated link will be assigned that name. Otherwise, a unique name for the link will be generated.\n\nAn error is raised if:\n\nPort classes are incorrect for the direction of the link.\nPorts in src or dest are already assigned to a link.\nA link with the given name already exists in c.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/constructors.html#Mapper2.MapperCore.build_mux",
    "page": "Architecture Constructors",
    "title": "Mapper2.MapperCore.build_mux",
    "category": "function",
    "text": "build_mux(inputs, outputs; metadata = Dict{String,Any}())\n\nBuild a mux with the specified number of inputs and outputs. Inputs and outputs will be named in[0], in[1], … , in[inputs-1] and outputs will be named out[0], out[1], … , out[outputs-1].\n\nIf metdata is supplied, the dictionary will be attached to the mux component itself as well as all ports and links in the mux component.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/constructors.html#Architecture-Constructors-1",
    "page": "Architecture Constructors",
    "title": "Architecture Constructors",
    "category": "section",
    "text": "MapperCore.add_port\nMapperCore.add_child\nMapperCore.add_link\nMapperCore.build_mux"
},

{
    "location": "man/architecture/constructors.html#Mapper2.MapperCore.Offset",
    "page": "Architecture Constructors",
    "title": "Mapper2.MapperCore.Offset",
    "category": "type",
    "text": "struct Offset\n\nFields\n\noffset\nOffset to add to a source address to reach a destination address\nsource_port\nName of the source port to start a link at.\ndest_port\nName of the destination port to end a link at.\n\nDocumentation\n\nSingle rule for connecting ports at the TopLevel\n\nMethod List\n\nOffset(offset, source_port, dest_port)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Constructors.jl:183.\n\nOffset(A, B, C)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Constructors.jl:192.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/constructors.html#Mapper2.MapperCore.ConnectionRule",
    "page": "Architecture Constructors",
    "title": "Mapper2.MapperCore.ConnectionRule",
    "category": "type",
    "text": "struct ConnectionRule\n\nFields\n\noffsets\nVector{Offset} - Collection of [Offset] rules to be applied to all source addresses that pass the filtering stage.\n\naddress_filter\nFunction - Filter for source addresses. Default: true\nsource_filter\nFunction - Filter for source components. Default: true\ndest_filter\nFunction - Filter for destination components. Default: true\n\nDocumentation\n\nGlobal connection rule for connecting ports at the TopLevel\n\nMethod List\n\nConnectionRule(offsets, address_filter, source_filter, dest_filter)\nConnectionRule(offsets, address_filter, source_filter, dest_filter)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Constructors.jl:198.\n\nConnectionRule(offsets; address_filter, source_filter, dest_filter)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Constructors.jl:220.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/constructors.html#Mapper2.MapperCore.connection_rule",
    "page": "Architecture Constructors",
    "title": "Mapper2.MapperCore.connection_rule",
    "category": "function",
    "text": "connection_rule(toplevel, rule::ConnectionRule; metadata = emptymeta())\n\nApply rule::ConnectionRule to toplevel. Source addresses will first be filtered by rule.address_filter. Then, for each filtered address, the [Component] at that address will be passed to  rule.source_filter. \n\nIf the component passes, all elements in rule.offsets will be  applied, assuming the component at destination address passes rule.dest_filter. A new link will then be created provided it is safe to do so.\n\nMethod List\n\nconnection_rule(toplevel, rule; kwargs...)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Constructors.jl:246.\n\nconnection_rule(toplevel, rule; metadata)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Architecture/Constructors.jl:255.\n\n\n\n\n\n"
},

{
    "location": "man/architecture/constructors.html#Creating-Links-at-the-[TopLevel](@ref)-1",
    "page": "Architecture Constructors",
    "title": "Creating Links at the TopLevel",
    "category": "section",
    "text": "MapperCore.Offset\nMapperCore.ConnectionRule\nMapperCore.connection_rule"
},

{
    "location": "man/taskgraph.html#",
    "page": "Taskgraph",
    "title": "Taskgraph",
    "category": "page",
    "text": ""
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.Taskgraph",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.Taskgraph",
    "category": "type",
    "text": "struct Taskgraph\n\nFields\n\nname\nThe name of the taskgraph\nnodes\nNodes in the taskgraph. Type: Dict{String, TaskgraphNode}\nedges\nEdges in the taskgraph. Type: Vector{TaskgraphEdge}\nnode_edges_out\nOutgoing adjacency list mapping node names to edge indices. Type: Dict{String, Vector{Int64}}\n\nnode_edges_in\nIncoming adjacency list mapping node names to edge indices. Type: Dict{String, Vector{Int64}}\n\nDocumentation\n\nData structure encoding tasks and their relationships.\n\nMethod List\n\nTaskgraph()\nTaskgraph(name)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Taskgraphs.jl:70.\n\nTaskgraph(name, nodes, edges)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Taskgraphs.jl:79.\n\nTaskgraph(nodes, edges)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Taskgraphs.jl:129.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Taskgraph-1",
    "page": "Taskgraph",
    "title": "Taskgraph",
    "category": "section",
    "text": "Pages = [\"taskgraph.md\"]MapperCore.Taskgraph"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.TaskgraphNode",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.TaskgraphNode",
    "category": "type",
    "text": "struct TaskgraphNode\n\nFields\n\nname\nThe name of this task.\nmetadata\n\nDocumentation\n\nSimple container representing a task in a taskgraph.\n\nMethod List\n\nTaskgraphNode(name; metadata)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Taskgraphs.jl:10.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.TaskgraphEdge",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.TaskgraphEdge",
    "category": "type",
    "text": "struct TaskgraphEdge\n\nFields\n\nsources\nSource task names.\nsinks\nSink task names.\nmetadata\n\nDocumentation\n\nSimple container representing an edge in a taskgraph.\n\nMethod List\n\nTaskgraphEdge(source, sink; metadata)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Taskgraphs.jl:24.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Important-Types-1",
    "page": "Taskgraph",
    "title": "Important Types",
    "category": "section",
    "text": "MapperCore.TaskgraphNode\nMapperCore.TaskgraphEdge"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.add_edge",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.add_edge",
    "category": "function",
    "text": "add_edge(taskgraph, edge)\n\n\nAdd a edge to taskgraph.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.add_node",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.add_node",
    "category": "function",
    "text": "add_node(taskgraph, node)\n\n\nAdd a node to taskgraph. Error if node already exists.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.getnodes",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.getnodes",
    "category": "function",
    "text": "getnodes(taskgraph)\n\n\nReturn an iterator of TaskgraphNode yielding all nodes in taskgraph.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.getnode",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.getnode",
    "category": "function",
    "text": "getnode(taskgraph, name)\n\n\nReturn the TaskgraphNode in taskgraph with name.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.getedges",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.getedges",
    "category": "function",
    "text": "getedges(taskgraph)\n\n\nReturn an iterator of TaskgraphEdge yielding all edges in taskgraph.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.getedge",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.getedge",
    "category": "function",
    "text": "getedge(taskgraph, index)\n\n\nReturn the TaskgraphEdge in taskgraph with index.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.nodenames",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.nodenames",
    "category": "function",
    "text": "nodenames(taskgraph)\n\n\nReturn an iterator yielding all names of nodes in taskgraph.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.num_nodes",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.num_nodes",
    "category": "function",
    "text": "num_nodes(taskgraph)\n\n\nReturn the number of nodes in taskgraph.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.num_edges",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.num_edges",
    "category": "function",
    "text": "num_edges(taskgraph)\n\n\nReturn the number of edges in taskgraph.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.getsources",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.getsources",
    "category": "function",
    "text": "getsources(taskgraph_edge)\n\n\nReturn the names of sources of a TaskgraphEdge.\n\n\n\n\n\ngetsources(taskgraph, edge)\n\n\nReturn Vector{TaskgraphNode} of sources for edge.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.getsinks",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.getsinks",
    "category": "function",
    "text": "getsinks(taskgraph_edge)\n\n\nReturn the names of sinks of a TaskgraphEdge.\n\n\n\n\n\ngetsinks(taskgraph, edge)\n\n\nReturn Vector{TaskgraphNode} of sinks for edge.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.hasnode",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.hasnode",
    "category": "function",
    "text": "hasnode(taskgraph, node)\n\n\nReturn true if taskgraph has a task named node.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.innodes",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.innodes",
    "category": "function",
    "text": "innodes(taskgraph, node)\n\n\nReturn Vector{TaskgraphNode} of unique nodes that are the source of an edge ending at node.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.innode_names",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.innode_names",
    "category": "function",
    "text": "innode_names(taskgraph, node)\n\n\nReturn Set{String} of names of unique nodes that are the source of an edges ending at node.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.outnodes",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.outnodes",
    "category": "function",
    "text": "outnodes(taskgraph, node)\n\n\nReturn Vector{TaskgraphNode} of unique nodes that are the sink of an edge starting at node.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#Mapper2.MapperCore.outnode_names",
    "page": "Taskgraph",
    "title": "Mapper2.MapperCore.outnode_names",
    "category": "function",
    "text": "outnode_names(taskgraph, node)\n\n\nReturn Set{String} of names of unique nodes that are the sink of an edges starting at node.\n\n\n\n\n\n"
},

{
    "location": "man/taskgraph.html#API-1",
    "page": "Taskgraph",
    "title": "API",
    "category": "section",
    "text": "MapperCore.add_edge\nMapperCore.add_node\nMapperCore.getnodes\nMapperCore.getnode\nMapperCore.getedges\nMapperCore.getedge\nMapperCore.nodenames\nMapperCore.num_nodes\nMapperCore.num_edges\nMapperCore.getsources\nMapperCore.getsinks\nMapperCore.hasnode\nMapperCore.innodes\nMapperCore.innode_names\nMapperCore.outnodes\nMapperCore.outnode_names"
},

{
    "location": "man/map.html#",
    "page": "Map",
    "title": "Map",
    "category": "page",
    "text": ""
},

{
    "location": "man/map.html#Mapper2.MapperCore.Map",
    "page": "Map",
    "title": "Mapper2.MapperCore.Map",
    "category": "type",
    "text": "mutable struct Map{D, T<:RuleSet}\n\nFields\n\nruleset\nRuleSet for assigning taskgraph to toplevel.\ntoplevel\nTopLevel{A,D} - The TopLevel to be used for the mapping.\ntaskgraph\nThe Taskgraph to map to the toplevel.\noptions\nmapping\nHow taskgraph is mapped to toplevel.\nmetadata\n\nDocumentation\n\nTop level data structure. Summary of parameters:\n\nT - The RuleSet used to control placement and routing.\nD - The number of dimensions in the architecture (will usually be 2 or 3).\n\nMethod List\n\nMap(ruleset, toplevel, taskgraph, options, mapping, metadata)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Map/Map.jl:42.\n\nMap(ruleset, toplevel, taskgraph; options, metadata)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Map/Map.jl:67.\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Mapper2.MapperCore.Mapping",
    "page": "Map",
    "title": "Mapper2.MapperCore.Mapping",
    "category": "type",
    "text": "mutable struct Mapping\n\nFields\n\nnodes\nDict{String, Path{Component}} - Takes a node name and returns the path to the Component where that node is mapped.\n\nedges\nVector{SparseDiGraph{Union{Path{Link},Path{Port},Path{Component}}}} - Takes a integer index for an edge in the parent Taskgraph and returns a graph whose node types Paths to architectural compoennts.o\nEdge connectivity in the graph describes how the TaskgraphEdge is routed through the TopLevel\n\nDocumentation\n\nRecord of how Taskgraphs and TaskgraphEdges in a  Taskgraph map to a TopLevel.\n\nMethod List\n\nMapping(nodes, edges)\nMapping(nodes, edges)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Map/Map.jl:13.\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Map-1",
    "page": "Map",
    "title": "Map",
    "category": "section",
    "text": "The Map holds both a TopLevel and a Taskgraph. An additional Mapping type records how the taskgraph maps to the  toplevel.MapperCore.Map\nMapperCore.Mapping"
},

{
    "location": "man/map.html#Mapper2.MapperCore.check_routing",
    "page": "Map",
    "title": "Mapper2.MapperCore.check_routing",
    "category": "function",
    "text": "check_routing(map; quiet)\n\n\nCheck routing in map. Return true if map passes all checks. Otherwise, return false. If quiet = false, print status of each test to STDOUT.\n\nChecks performed:\n\ncheck_placement\ncheck_ports\ncheck_capacity\ncheck_architecture_connectivity\ncheck_routing_connectivity\ncheck_architecture_resources\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Mapper2.MapperCore.check_placement",
    "page": "Map",
    "title": "Mapper2.MapperCore.check_placement",
    "category": "function",
    "text": "check_placement(map)\n\n\nEnsure that each TaskgraphNode is mapped to a valid component.\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Mapper2.MapperCore.check_ports",
    "page": "Map",
    "title": "Mapper2.MapperCore.check_ports",
    "category": "function",
    "text": "check_ports(m::Map{A}) where A\n\nCheck the source and destination ports for each task in m. Perform the  following checks:\n\nEach source and destination port for each task channel is valid.\nAll sources and destinations for each task channel has been assigned to   a port.\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Mapper2.MapperCore.check_capacity",
    "page": "Map",
    "title": "Mapper2.MapperCore.check_capacity",
    "category": "function",
    "text": "check_capacity(m::Map)\n\nPerforms the following checks:\n\nThe number of channels assigned to each routing resource in m.toplevel   does not exceed the stated capacity of that resource.\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Mapper2.MapperCore.check_architecture_connectivity",
    "page": "Map",
    "title": "Mapper2.MapperCore.check_architecture_connectivity",
    "category": "function",
    "text": "check_architecture_connectivity(m::Map)\n\nTraverse the routing for each channel in m.taskgraph. Check:\n\nThe nodes on each side of an edge in the routing graph are actually connected   in the underlying architecture.\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Mapper2.MapperCore.check_routing_connectivity",
    "page": "Map",
    "title": "Mapper2.MapperCore.check_routing_connectivity",
    "category": "function",
    "text": "check_routing_connectivity(m::Map)\n\nPerform the following check:\n\nCheck that the routing graph for each channel in m.taskgraph is weakly    connected.\nEnsure there is a valid path from each source of the routing graph to each   destination of the routing graph.\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Mapper2.MapperCore.check_architecture_resources",
    "page": "Map",
    "title": "Mapper2.MapperCore.check_architecture_resources",
    "category": "function",
    "text": "check_architecture_resources(map::Map)\n\nTraverse the routing graph for each channel in m.taskgraph. Check:\n\nThe routing resources used by each channel are valid for that type of channel.\n\n\n\n\n\n"
},

{
    "location": "man/map.html#Verification-Routines-1",
    "page": "Map",
    "title": "Verification Routines",
    "category": "section",
    "text": "Verify the result of placement and routing.MapperCore.check_routing\nMapperCore.check_placement\nMapperCore.check_ports\nMapperCore.check_capacity\nMapperCore.check_architecture_connectivity\nMapperCore.check_routing_connectivity\nMapperCore.check_architecture_resources"
},

{
    "location": "man/extensions.html#",
    "page": "Extensions",
    "title": "Extensions",
    "category": "page",
    "text": ""
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.isspecial",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.isspecial",
    "category": "function",
    "text": "isspecial(ruleset::RuleSet, taskgraphnode::TaskgraphNode) :: Bool\n\nReturn true to disable move distance contraction for taskgraphnode during placement under ruleset.\n\nDefault: false\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.isequivalent",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.isequivalent",
    "category": "function",
    "text": "isequivalent(ruleset::RuleSet, a::TaskgraphNode, b::TaskgraphNode) :: Bool\n\nReturn true if TaskgraphNodes a and b are semantically equivalent for placement.\n\nDefault: true\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.ismappable",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.ismappable",
    "category": "function",
    "text": "ismappable(ruleset::RuleSet, component::Component) :: Bool\n\nReturn true if some task can be mapped to component under ruleset.\n\nDefault: true\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.canmap",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.canmap",
    "category": "function",
    "text": "canmap(ruleset::RuleSet, t::TaskgraphNode, c::Component) :: Bool\n\nReturn true if t can be mapped to c under ruleset.\n\nDefault: true\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.canuse",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.canuse",
    "category": "function",
    "text": "canuse(ruleset::RuleSet, item::Union{Port,Link,Component}, edge::TaskgraphEdge)::Bool\n\nReturn true if edge can use item as a routing resource under ruleset.\n\nDefault: true\n\n\n\n\n\ncanuse(ruleset::RuleSet, link::RoutingLink, channel::RoutingChannel)::Bool\n\nReturn true if channel can be routed using link.\n\nSee: RoutingLink, RoutingChannel\n\nDefault: true\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.getcapacity",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.getcapacity",
    "category": "function",
    "text": "getcapacity(ruleset::RuleSet, item::Union{Port,Link,Component})\n\nReturn the capacity of routing resource item under ruleset.\n\nDefault: 1\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.is_source_port",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.is_source_port",
    "category": "function",
    "text": "is_source_port(ruleset::RuleSet, port::Port, edge::TaskgraphEdge)::Bool\n\nReturn true if port is a valid source port for edge under ruleset.\n\nDefault: true\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.is_sink_port",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.is_sink_port",
    "category": "function",
    "text": "is_sink_port(ruleset::RuleSet, port::Port, edge::TaskgraphEdge)::Bool\n\nReturn true if port is a vlid sink port for edge under ruleset.\n\nDefault: true\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.MapperCore.needsrouting",
    "page": "Extensions",
    "title": "Mapper2.MapperCore.needsrouting",
    "category": "function",
    "text": "needsrouting(ruleset::RuleSet, edge::TaskgraphEdge)::Bool\n\nReturn true if edge needs to be routed under ruleset.\n\nDefault: true\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Mapper2.Routing.annotate",
    "page": "Extensions",
    "title": "Mapper2.Routing.annotate",
    "category": "function",
    "text": "annotate(ruleset::RuleSet, item::Union{Port,Link,Component})\n\nReturn some <:RoutingLink for item.  If  item <: Component, it is a primitive. If not other primitives have been  defined, it will be a mux.\n\nSee: BasicRoutingLink\n\nDefault: `BasicRoutingLink(capacity = getcapacity(ruleset, item))\n\n\n\n\n\n"
},

{
    "location": "man/extensions.html#Extensions-1",
    "page": "Extensions",
    "title": "Extensions",
    "category": "section",
    "text": "The Mapper framework is designed to alter behavior mapping behavior using a certain set of core functions that are extended as needed for new subtypes of RuleSet. These methods only need to be extended if the default behavior is not sufficient.In addition, placement and routing have types and methods that can be extended as well to more finely tune mapping.MapperCore.isspecial\nMapperCore.isequivalent\nMapperCore.ismappable\nMapperCore.canmap\nMapperCore.canuse\nMapperCore.getcapacity\nMapperCore.is_source_port\nMapperCore.is_sink_port\nMapperCore.needsrouting\nRouting.annotate"
},

{
    "location": "man/SA/placement.html#",
    "page": "Simulated Annealing",
    "title": "Simulated Annealing",
    "category": "page",
    "text": ""
},

{
    "location": "man/SA/placement.html#Mapper2.SA.place!",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.place!",
    "category": "function",
    "text": "place!(map::Map; kwargs...) :: SAState\n\nRun simulated annealing placement directly on map.\n\nRecords the following metrics into map.metadata:\n\nplacement_struct_time - Amount of time it took to build the    SAStruct from map.\nplacement_struct_bytes - Number of bytes allocated during the construction   of the SAStruct\nplacement_time - Running time of placement.\nplacement_bytes - Number of bytes allocated during placement.\nplacement_objective - Final objective value of placement.\n\nKeyword Arguments\n\nseed - Seed to provide the random number generator. Specify this to a    constant value for consistent results from run to run.\nDefault: rand(UInt64)\nmove_attempts :: Integer - Number of successful moves to generate between   state updates. State updates include adjusting temperature, move distance   limit, state displaying etc.\nHigher numbers will generally yield higher quality placement but with a   longer running time.\nDefault: 20000\ninitial_temperature :: Float64 - Initial temperature that the system begins   its warming process at. Due to the warming procedure, this should not have   much of an affect on placement.\nDefault: 1.0.\nsupplied_state :: Union{SAState,Nothing} - State type to use for this    placement. Can be used to resume placement where it left off from a previous   run. If nothing, a new SAState object will be initialized.\nDefault: nothing\nmovegen :: MoveGenerator - The MoveGenerator to use for this    placement.\nDefault: CachedMoveGenerator\nwarmer - The SAWarm warming schedule to use.\nDefault: DefaultSAWarm\ncooler - The SACool cooling schedule to use.\nDefault: DefaultSACool\nlimiter - The SALimit move distance limiting algorithm to    use.\nDefault: DefaultSALimit\ndoner - The SADone exit condition to use.\nDefault: DefaultSADone\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Simulated-Annealing-1",
    "page": "Simulated Annealing",
    "title": "Simulated Annealing",
    "category": "section",
    "text": "SA.place!"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.SAState",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.SAState",
    "category": "type",
    "text": "mutable struct SAState\n\nFields\n\ntemperature\nCurrent Temperature of the system.\nobjective\nCurrent objective value.\ndistance_limit\nCurrent distance limit.\ndistance_limit_int\nCurrent distance limit as an integer.\nmax_distance_limit\nMaximum distance limit for this architecture.\nrecent_move_attempts\nrecent_successful_moves\nrecent_accepted_moves\nrecent_deviation\nwarming\nCurrent warming state\ntotal_moves\nTotal number of move attempts made\nsuccessful_moves\nNumber of successful move generations\naccepted_moves\nNumber of moves accepted\nmoves_per_second\nMoves per second\ndeviation\nAverage Deviaation\nstart_time\nCreation time of the structure\nrun_time\nRunning Time - only an approximate measure\ndisplay_updates\nlast_update_time\nTime of the last update\ndt\nUpdate Interval\naux_cost\nAuxiliary cost\n\nDocumentation\n\nState tracking struct for Simulated Annealing placement.\n\nMethod List\n\nSAState(temperature, distance_limit, objective)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/State.jl:57.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#SAState-1",
    "page": "Simulated Annealing",
    "title": "SAState",
    "category": "section",
    "text": "SA.SAState"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.SAWarm",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.SAWarm",
    "category": "type",
    "text": "abstract type SAWarm\n\nFields\n\nDocumentation\n\nAbstract type controlling the warming cycle of Simulated Annealing placement.\n\nAPI\n\nwarm!\n\nImplementations\n\nDefaultSAWarm\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.warm!",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.warm!",
    "category": "function",
    "text": "warm!(warmer :: SAWarm, state :: SAState)\n\nIncrease state.temperature according to warmer. If warmer decides that the system is done warming up, it must set state.warming = false.\n\nMethod List\n\nwarm!(w, state)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Algorithm.jl:79.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.DefaultSAWarm",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.DefaultSAWarm",
    "category": "type",
    "text": "mutable struct DefaultSAWarm <: Mapper2.SA.SAWarm\n\nFields\n\nratio\nmultiplier\ndecay\n\nDocumentation\n\nDefault imeplementation of SAWarm.\n\nOn each invocation, will multiply the temperature of the anneal by multiplier. When the acceptance ratio rises above ratio, warming routine will end.\n\nTo prevent unbounded warming, the ratio field is multiplied by the decay field on each invocation.\n\nMethod List\n\nDefaultSAWarm(ratio, multiplier, decay)\nDefaultSAWarm(ratio, multiplier, decay)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Algorithm.jl:72.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Warming-1",
    "page": "Simulated Annealing",
    "title": "Warming",
    "category": "section",
    "text": "Warming involve increasing the temperature of the simulated annealing system until certain criteria are reached, at which the true simulated annealing algorithm takes place. It is important to begin a placement at a high  temperature because this early phase is responsible for creating a high level  idea for what the final placement will look like. The default implementation described below heats up the the system until a  certain high fraction of generated moves are accepted, allowing the initial  temperature to depend on the specific characteristics of the architecture and taskgraph being placed.SA.SAWarm\nSA.warm!\nSA.DefaultSAWarm"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.SACool",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.SACool",
    "category": "type",
    "text": "abstract type SACool\n\nFields\n\nDocumentation\n\nCooling schedule for Simulated Annealing placement.\n\nAPI\n\ncool!\n\nImplementations\n\nDefaultSACool\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.cool!",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.cool!",
    "category": "function",
    "text": "cool!(cooler :: SACool, state :: SAState)\n\nWhen called, may decrease state.temperature.\n\nMethod List\n\ncool!(c, state)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Algorithm.jl:140.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.DefaultSACool",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.DefaultSACool",
    "category": "type",
    "text": "struct DefaultSACool <: Mapper2.SA.SACool\n\nFields\n\nalpha\n\nDocumentation\n\nDefault cooling schedule. Each invocation, will multiply the temperature of the anneal by the alpha parameter.\n\nMethod List\n\nDefaultSACool(alpha)\nDefaultSACool(alpha)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Algorithm.jl:137.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Cooling-1",
    "page": "Simulated Annealing",
    "title": "Cooling",
    "category": "section",
    "text": "Over the course of simulated annealing placement, the temperature of the system is slowly lowered, increasing the probability that an objective-increasing move will be rejected. The simplest is multiplying the temperature by a common factor alpha  1 soT_new = alpha T_oldRasing the value of alpha results in higher quality results at the cost of a longer run time.SA.SACool\nSA.cool!\nSA.DefaultSACool"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.SALimit",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.SALimit",
    "category": "type",
    "text": "abstract type SALimit\n\nFields\n\nDocumentation\n\nType that controls the length contraction mechanism of Simulated Annealing placement.\n\nAPI\n\nlimit!\n\nImplmementations\n\nDefaultSALimit\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.limit!",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.limit!",
    "category": "function",
    "text": "limit!(limiter :: SALimit, state :: SAState)\n\nMutate state.distance_limit when called.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.DefaultSALimit",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.DefaultSALimit",
    "category": "type",
    "text": "struct DefaultSALimit <: Mapper2.SA.SALimit\n\nFields\n\nratio\nminimum\n\nDocumentation\n\nDefault distance limit updater. Will adjust the distance limit so approximate ratio of moves are accepted. Will not set state.limit lower than minimum.\n\nMethod List\n\nDefaultSALimit(ratio, minimum)\nDefaultSALimit(ratio, minimum)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Algorithm.jl:180.\n\nDefaultSALimit(ratio)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Algorithm.jl:184.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Move-Distance-Limiting-1",
    "page": "Simulated Annealing",
    "title": "Move Distance Limiting",
    "category": "section",
    "text": "TODOSA.SALimit\nSA.limit!\nSA.DefaultSALimit"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.SADone",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.SADone",
    "category": "type",
    "text": "abstract type SADone\n\nFields\n\nDocumentation\n\nControl when to terminate Simulated Annealing placement.\n\nAPI\n\nsa_done\n\nImplementations\n\n[DefaultSADone]\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.sa_done",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.sa_done",
    "category": "function",
    "text": "sa_done(doner :: SADone, state :: SAState)\n\nReturn true to finish placement.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Mapper2.SA.DefaultSADone",
    "page": "Simulated Annealing",
    "title": "Mapper2.SA.DefaultSADone",
    "category": "type",
    "text": "struct DefaultSADone <: Mapper2.SA.SADone\n\nFields\n\natol\n\nDocumentation\n\nDefault end detection. Will return true when objective deviation is less than atol.\n\nMethod List\n\nDefaultSADone(atol)\nDefaultSADone(atol)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Algorithm.jl:238.\n\n\n\n\n\n"
},

{
    "location": "man/SA/placement.html#Terminating-Placement-1",
    "page": "Simulated Annealing",
    "title": "Terminating Placement",
    "category": "section",
    "text": "TODOSA.SADone\nSA.sa_done\nSA.DefaultSADone"
},

{
    "location": "man/SA/sastruct.html#",
    "page": "SAStruct",
    "title": "SAStruct",
    "category": "page",
    "text": ""
},

{
    "location": "man/SA/sastruct.html#Mapper2.SA.SAStruct",
    "page": "SAStruct",
    "title": "Mapper2.SA.SAStruct",
    "category": "type",
    "text": "struct SAStruct{T<:RuleSet, U<:Mapper2.SA.SADistance, D, N<:Mapper2.SA.SANode, L<:Mapper2.SA.SAChannel, M<:Mapper2.SA.AbstractMapTable, A<:Mapper2.SA.AddressData, Q}\n\nFields\n\nruleset\nnodes\nVector{N}: Container of nodes.\nchannels\nVector{L}: Container of edges.\nmaptable\ndistance\ngrid\naddress_data\naux\npathtable\ntasktable\n\nDocumentation\n\nDatastructure for simulated annealing placement.\n\nImportant parameters:\n\nA - The concrete Architecture type.\n\nConstructor\n\nArguments:\n\nm: The Map to translate into an SAStruct.\n\nKeyword Arguments:\n\ndistance: The distance type to use. Defaults: BasicDistance\nenable_flattness :: Bool: Enable the flat architecture optimization if   it is applicable. Default: true.\nenable_address :: Bool: Enable address-specific data to be incorporated   into the struct. Default: false.\naux: Auxiliary data struct to provide any extra information that may be   needed for specializations of placement. Default: nothing.\n\nMethod List\n\nSAStruct(ruleset, nodes, channels, maptable, distance, grid, address_data, aux, pathtable, tasktable)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Struct.jl:171.\n\nSAStruct(m; enable_address, aux, kwargs...)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Struct.jl:338.\n\n\n\n\n\n"
},

{
    "location": "man/SA/sastruct.html#SAStruct-1",
    "page": "SAStruct",
    "title": "SAStruct",
    "category": "section",
    "text": "The central data structure for simulated annealing placement is the  SAStruct. Before placement, this data type will be created from the Map and the main loop of placement will occur using this structure.After placement, the final location of tasks will be recorded from the  SAStruct back into the parent Map.SA.SAStruct"
},

{
    "location": "man/SA/sastruct.html#Flat-Architecture-Optimization-1",
    "page": "SAStruct",
    "title": "Flat Architecture Optimization",
    "category": "section",
    "text": "In the general case, any given address in the TopLevel may have multiple mappable components. Simulated annealing placement completely supports this  general case. However, doing so adds overhead as the available and valid slots within each address must be traced using Vectors, which addes extra pointer dereferencing during placement.If this optimization is enabled and the TopLevel structure contains only a  single mappable component per address, the \"Flat Architecture Optimization\" will be applied. Practically, this means that the locations of nodes in the SAStruct will be tracked using CartesianIndices rather than Locations, and some tracking vectors in the SAStruct\'s MapTable can be simplified to Bools.Overall, it allows for much faster placement when this optimization can be  applied without sacrificing the generality of placement when it cannot."
},

{
    "location": "man/SA/sastruct.html#Construction-Pipeline-1",
    "page": "SAStruct",
    "title": "Construction Pipeline",
    "category": "section",
    "text": "SA.task_equivalence_classes"
},

{
    "location": "man/SA/methods.html#",
    "page": "Extentable Methods",
    "title": "Extentable Methods",
    "category": "page",
    "text": ""
},

{
    "location": "man/SA/methods.html#Extentable-Methods-1",
    "page": "Extentable Methods",
    "title": "Extentable Methods",
    "category": "section",
    "text": "This sections describes the list of methods that can be extended to exercise finer control during placement."
},

{
    "location": "man/SA/methods.html#Mapper2.SA.assign-Tuple{SAStruct,Any,Any}",
    "page": "Extentable Methods",
    "title": "Mapper2.SA.assign",
    "category": "method",
    "text": "assign(sa_struct, index, new_location)\n\n\nMove node at index to new_location.\n\n\n\n\n\n"
},

{
    "location": "man/SA/methods.html#Mapper2.SA.move",
    "page": "Extentable Methods",
    "title": "Mapper2.SA.move",
    "category": "function",
    "text": "move(sa_struct, index, new_location)\n\n\nMove node at index from its current location to new_location.\n\n\n\n\n\n"
},

{
    "location": "man/SA/methods.html#Mapper2.SA.swap",
    "page": "Extentable Methods",
    "title": "Mapper2.SA.swap",
    "category": "function",
    "text": "swap(sa_struct, node1_idx, node2_idx)\n\n\nSwap the locations of two nodes with indices node1_idx and node2_idx.\n\n\n\n\n\n"
},

{
    "location": "man/SA/methods.html#Move-Methods-1",
    "page": "Extentable Methods",
    "title": "Move Methods",
    "category": "section",
    "text": "SA.assign(::SA.SAStruct, ::Any, ::Any)\nSA.move\nSA.swap"
},

{
    "location": "man/SA/methods.html#Mapper2.SA.channel_cost",
    "page": "Extentable Methods",
    "title": "Mapper2.SA.channel_cost",
    "category": "function",
    "text": "channel_cost(sa_struct{T}, channel :: SAChannel) where {T <: RuleSet}\n\nReturn the cost of channel. Default implementation accumulates the distances between the source and sink addresses of the channel using sa_struct.distance.\n\nMethod List\n\nchannel_cost(sa_struct, channel)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Methods.jl:85.\n\n\n\n\n\n"
},

{
    "location": "man/SA/methods.html#Mapper2.SA.node_cost",
    "page": "Extentable Methods",
    "title": "Mapper2.SA.node_cost",
    "category": "function",
    "text": "node_cost(sa_struct{T}, idx) where {T <: RuleSet}\n\nReturn the cost of the node with index idx in ruleset T.\n\nDefault implementation sums the node\'s:\n\nincoming channels\noutgoing channels\naddress cost\nauxiliary cost.\n\nMethod List\n\nnode_cost(sa_struct, idx)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Methods.jl:162.\n\n\n\n\n\n"
},

{
    "location": "man/SA/methods.html#Mapper2.SA.node_pair_cost",
    "page": "Extentable Methods",
    "title": "Mapper2.SA.node_pair_cost",
    "category": "function",
    "text": "node_pair_cost(sa_struct{T}, idx1, idx2) where {T <: RuleSet}\n\nCompute the cost of the pair of nodes with indices idx1 and idx2. Call this function when computing the cost of two nodes because in general, the total cost of two nodes is not the sum of the individual nodes\' costs.\n\nMethod List\n\nnode_pair_cost(sa_struct, idx1, idx2)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Methods.jl:198.\n\n\n\n\n\n"
},

{
    "location": "man/SA/methods.html#Mapper2.SA.address_cost",
    "page": "Extentable Methods",
    "title": "Mapper2.SA.address_cost",
    "category": "function",
    "text": "address_cost(sa_struct{T}, node :: SANode, address_data::AddressData) where {T <: RuleSet}\n\nReturn the address cost for node for RuleSet T. Default return value is zero(Float64).\n\nCalled by default during node_cost and node_pair_cost\n\nMethod List\n\naddress_cost(sa_struct, node, address_data)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Methods.jl:113.\n\naddress_cost(sa_struct, node, address_data)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Methods.jl:114.\n\n\n\n\n\n"
},

{
    "location": "man/SA/methods.html#Mapper2.SA.aux_cost",
    "page": "Extentable Methods",
    "title": "Mapper2.SA.aux_cost",
    "category": "function",
    "text": "aux_cost(sa_struct{T}) where {T <: RuleSet}\n\nReturn an auxiliary cost associated with the entire mapping of the sa_struct. May use any field of sa_struct but may only mutate sa_struct.aux.\n\nDefault: zero(Float64)\n\nMethod List\n\naux_cost(sa_struct)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Methods.jl:131.\n\n\n\n\n\n"
},

{
    "location": "man/SA/methods.html#Cost-Methods-1",
    "page": "Extentable Methods",
    "title": "Cost Methods",
    "category": "section",
    "text": "SA.channel_cost\nSA.node_cost\nSA.node_pair_cost\nSA.address_cost\nSA.aux_cost"
},

{
    "location": "man/SA/types.html#",
    "page": "Extendable Types",
    "title": "Extendable Types",
    "category": "page",
    "text": ""
},

{
    "location": "man/SA/types.html#Extendable-Types-1",
    "page": "Extendable Types",
    "title": "Extendable Types",
    "category": "section",
    "text": ""
},

{
    "location": "man/SA/types.html#Mapper2.SA.SANode",
    "page": "Extendable Types",
    "title": "Mapper2.SA.SANode",
    "category": "type",
    "text": "abstract type SANode\n\nFields\n\nDocumentation\n\nAbstract super types for the SA representation of TaskgraphNodes.\n\nAPI\n\nlocation\nassign\ngetclass\nsetclass!\n\nImplementations\n\nBasicNode\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#SANode-1",
    "page": "Extendable Types",
    "title": "SANode",
    "category": "section",
    "text": "SA.SANode"
},

{
    "location": "man/SA/types.html#Mapper2.SA.location",
    "page": "Extendable Types",
    "title": "Mapper2.SA.location",
    "category": "function",
    "text": "location(node::SANode{T}) :: T\n\nReturn the location of node. Must be parameterized by T.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Mapper2.SA.assign",
    "page": "Extendable Types",
    "title": "Mapper2.SA.assign",
    "category": "function",
    "text": "assign(node::SANode{T}, location::T)\n\nSet the location of node to location.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Mapper2.SA.getclass",
    "page": "Extendable Types",
    "title": "Mapper2.SA.getclass",
    "category": "function",
    "text": "getclass(node)\n\nReturn the class of node.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Mapper2.SA.setclass!",
    "page": "Extendable Types",
    "title": "Mapper2.SA.setclass!",
    "category": "function",
    "text": "setclass!(node, class::Integer)\n\nSet the class of node to class.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#API-1",
    "page": "Extendable Types",
    "title": "API",
    "category": "section",
    "text": "SA.location\nSA.assign\nSA.getclass\nSA.setclass!"
},

{
    "location": "man/SA/types.html#Mapper2.SA.BasicNode",
    "page": "Extendable Types",
    "title": "Mapper2.SA.BasicNode",
    "category": "type",
    "text": "mutable struct BasicNode{T} <: Mapper2.SA.SANode\n\nFields\n\nlocation\nLocation this node is assigned in the architecture. Must be parametric.\nclass\nThe class of this node.\noutchannels\nAdjacency list of outgoing channels.\ninchannels\nAdjacency list of incoming channels.\n\nDocumentation\n\nThe standard implementation of SANode.\n\nMethod List\n\nBasicNode(location, class, outchannels, inchannels)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Struct.jl:206.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Implementations-1",
    "page": "Extendable Types",
    "title": "Implementations",
    "category": "section",
    "text": "SA.BasicNode"
},

{
    "location": "man/SA/types.html#Mapper2.SA.SAChannel",
    "page": "Extendable Types",
    "title": "Mapper2.SA.SAChannel",
    "category": "type",
    "text": "abstract type SAChannel\n\nFields\n\nDocumentation\n\nSAStruct representation of a TaskgraphEdge. Comes in two varieties: TwoChannel and MultiChannel\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Mapper2.SA.TwoChannel",
    "page": "Extendable Types",
    "title": "Mapper2.SA.TwoChannel",
    "category": "type",
    "text": "abstract type TwoChannel <: Mapper2.SA.SAChannel\n\nFields\n\nDocumentation\n\nAbstract supertype for channels with only one source and sink.\n\nRequired Fields\n\nsource::Int64\nsink::Int64\n\nImplementations\n\nBasicChannel\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Mapper2.SA.MultiChannel",
    "page": "Extendable Types",
    "title": "Mapper2.SA.MultiChannel",
    "category": "type",
    "text": "abstract type MultiChannel <: Mapper2.SA.SAChannel\n\nFields\n\nDocumentation\n\nAbstract supertype for channels with multiple sources/sinks.\n\nRequired Fields\n\nsources::Vector{Int}\nsinks::Vector{Int}\n\nImplementations\n\nBasicMultiChannel\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#SAChannel-1",
    "page": "Extendable Types",
    "title": "SAChannel",
    "category": "section",
    "text": "SA.SAChannel\nSA.TwoChannel\nSA.MultiChannel"
},

{
    "location": "man/SA/types.html#Mapper2.SA.BasicChannel",
    "page": "Extendable Types",
    "title": "Mapper2.SA.BasicChannel",
    "category": "type",
    "text": "struct BasicChannel <: Mapper2.SA.TwoChannel\n\nFields\n\nsource\nsink\n\nDocumentation\n\nBasic Implementation of TwoChannel\n\nMethod List\n\nBasicChannel(source, sink)\nBasicChannel(source, sink)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Struct.jl:246.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Mapper2.SA.BasicMultiChannel",
    "page": "Extendable Types",
    "title": "Mapper2.SA.BasicMultiChannel",
    "category": "type",
    "text": "struct BasicMultiChannel <: Mapper2.SA.MultiChannel\n\nFields\n\nsources\nsinks\n\nDocumentation\n\nBasic Implementation of MultiChannel\n\nMethod List\n\nBasicMultiChannel(sources, sinks)\nBasicMultiChannel(sources, sinks)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Struct.jl:252.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Implementations-2",
    "page": "Extendable Types",
    "title": "Implementations",
    "category": "section",
    "text": "SA.BasicChannel\nSA.BasicMultiChannel"
},

{
    "location": "man/SA/types.html#Mapper2.SA.AddressData",
    "page": "Extendable Types",
    "title": "Mapper2.SA.AddressData",
    "category": "type",
    "text": "abstract type AddressData\n\nFields\n\nDocumentation\n\nSupertype for containers of data for address specific placement. There is no API for this type since the specific needs of address data vary between applications. If a custom type is used, extend [address_cost] to get the desired behavior.\n\nImplementations\n\nEmptyAddressData\nDefaultAddressData\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Mapper2.SA.EmptyAddressData",
    "page": "Extendable Types",
    "title": "Mapper2.SA.EmptyAddressData",
    "category": "type",
    "text": "struct EmptyAddressData <: Mapper2.SA.AddressData\n\nFields\n\nDocumentation\n\nNull representation of AddressData. Used when there is no address data to be used during placement.\n\nMethod List\n\nEmptyAddressData()\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Struct.jl:113.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Mapper2.SA.DefaultAddressData",
    "page": "Extendable Types",
    "title": "Mapper2.SA.DefaultAddressData",
    "category": "type",
    "text": "struct DefaultAddressData{U, T} <: Mapper2.SA.AddressData\n\nFields\n\ndict\n\nDocumentation\n\nDefault implementation of address data when it is to be used. In its normal state, it is just a wrapper for a Dict mapping addresses to a cost. Look at the implementation of address_cost to see how this is used. This function may be exteneded on node to provide different behavior.\n\nTo use this type, the method address_data must be defined to encode the values for the dict.\n\nMethod List\n\nDefaultAddressData(dict)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Struct.jl:126.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#AddressData-1",
    "page": "Extendable Types",
    "title": "AddressData",
    "category": "section",
    "text": "SA.AddressData\nSA.EmptyAddressData\nSA.DefaultAddressData"
},

{
    "location": "man/SA/types.html#Mapper2.SA.address_data",
    "page": "Extendable Types",
    "title": "Mapper2.SA.address_data",
    "category": "function",
    "text": "address_data(ruleset::RuleSet, component::Component) :: T where T\n\nReturn some token representing address specific data for component under ruleset.\n\n\n\n\n\n"
},

{
    "location": "man/SA/types.html#Methods-for-custom-extension-1",
    "page": "Extendable Types",
    "title": "Methods for custom extension",
    "category": "section",
    "text": "SA.address_data"
},

{
    "location": "man/SA/distance.html#",
    "page": "SADistance",
    "title": "SADistance",
    "category": "page",
    "text": ""
},

{
    "location": "man/SA/distance.html#Mapper2.SA.SADistance",
    "page": "SADistance",
    "title": "Mapper2.SA.SADistance",
    "category": "type",
    "text": "abstract type SADistance\n\nFields\n\nDocumentation\n\nAbstract distance type for placement.\n\nAPI\n\ngetdistance\nmaxdistance\n\nBasic Implementation\n\nBasicDistance\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/distance.html#SADistance-1",
    "page": "SADistance",
    "title": "SADistance",
    "category": "section",
    "text": "SA.SADistance"
},

{
    "location": "man/SA/distance.html#Mapper2.SA.getdistance",
    "page": "SADistance",
    "title": "Mapper2.SA.getdistance",
    "category": "function",
    "text": "getdistance(A::SADistance, a, b)\n\nReturn the distance from a to b with respect to A. Both a and b will implement getaddress.\n\nMethod List\n\ngetdistance(A, a, b)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Distance.jl:67.\n\n\n\n\n\n"
},

{
    "location": "man/SA/distance.html#Mapper2.SA.maxdistance",
    "page": "SADistance",
    "title": "Mapper2.SA.maxdistance",
    "category": "function",
    "text": "maxdistance(sa_struct, A::SADistance)\n\nReturn the maximum distance value of that occurs in sa_struct using the distance metric imposed by A.\n\nMethod List\n\nmaxdistance(sa_struct, A)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Distance.jl:69.\n\n\n\n\n\n"
},

{
    "location": "man/SA/distance.html#API-1",
    "page": "SADistance",
    "title": "API",
    "category": "section",
    "text": "SA.getdistance\nSA.maxdistance"
},

{
    "location": "man/SA/distance.html#Mapper2.SA.BasicDistance",
    "page": "SADistance",
    "title": "Mapper2.SA.BasicDistance",
    "category": "type",
    "text": "struct BasicDistance{D} <: Mapper2.SA.SADistance\n\nFields\n\ntable\nSimple look up table indexed by pairs of addresses. Returned value is the distance between the two addresses.\nIf an architecture has dimension \"N\", then the dimension of table is 2N.\n\nDocumentation\n\nBasic implementation of SADistance. Constructs a look up table of distances between all address pairs. Addresses have a distance of 1 if there exists even one link between components at those addresses.\n\nMethod List\n\nBasicDistance(table)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Distance.jl:56.\n\nBasicDistance(toplevel, pathtable)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/Distance.jl:76.\n\n\n\n\n\n"
},

{
    "location": "man/SA/distance.html#Implementations-1",
    "page": "SADistance",
    "title": "Implementations",
    "category": "section",
    "text": "SA.BasicDistance"
},

{
    "location": "man/SA/move_generators.html#",
    "page": "Move Generators",
    "title": "Move Generators",
    "category": "page",
    "text": ""
},

{
    "location": "man/SA/move_generators.html#Mapper2.SA.MoveGenerator",
    "page": "Move Generators",
    "title": "Mapper2.SA.MoveGenerator",
    "category": "type",
    "text": "abstract type MoveGenerator\n\nFields\n\nDocumentation\n\nAPI\n\ngenerate_move\ndistancelimit\ninitialize!\nupdate!\n\nImplementations\n\nSearchMoveGenerator\nCachedMoveGenerator\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/move_generators.html#Move-Generators-1",
    "page": "Move Generators",
    "title": "Move Generators",
    "category": "section",
    "text": "Move generators (believe it or not) generate moves in the inner loop of simulated annealing placement.SA.MoveGenerator"
},

{
    "location": "man/SA/move_generators.html#Mapper2.SA.generate_move",
    "page": "Move Generators",
    "title": "Mapper2.SA.generate_move",
    "category": "function",
    "text": "generate_move(sa_struct, move_generator, node_idx)\n\nGenerate a valid for move for the node with index node_idx in sa_struct. If isflat(sa_struct) == true, return CartesianIndex{D} where D = dimension(sa_struct). Otherwise, return Location{D}.\n\n\n\n\n\n"
},

{
    "location": "man/SA/move_generators.html#Mapper2.SA.distancelimit",
    "page": "Move Generators",
    "title": "Mapper2.SA.distancelimit",
    "category": "function",
    "text": "distancelimit(move_generator, sa_struct)\n\nReturn the maximum move distance of move_generator for sa_struct.\n\n\n\n\n\n"
},

{
    "location": "man/SA/move_generators.html#Mapper2.SA.initialize!",
    "page": "Move Generators",
    "title": "Mapper2.SA.initialize!",
    "category": "function",
    "text": "initialize!(move_generator, sa_struct, [limit = distancelimit(move_generator, sa_struct)])\n\nInitialize the state of move_generator based on sa_struct. Common operations include establishing an initial move distance limit or caching a list of possible moves.\n\nIf an initial limit is not supplied, it defaults to the maximum limit of the move generator for the given architecture.\n\n\n\n\n\n"
},

{
    "location": "man/SA/move_generators.html#Mapper2.SA.update!",
    "page": "Move Generators",
    "title": "Mapper2.SA.update!",
    "category": "function",
    "text": "update!(move_generator, sa_struct, limit)\n\nUpdate the move generator to a new move distance limit.\n\n\n\n\n\n"
},

{
    "location": "man/SA/move_generators.html#API-1",
    "page": "Move Generators",
    "title": "API",
    "category": "section",
    "text": "SA.generate_move\nSA.distancelimit\nSA.initialize!\nSA.update!"
},

{
    "location": "man/SA/move_generators.html#Implementations-1",
    "page": "Move Generators",
    "title": "Implementations",
    "category": "section",
    "text": ""
},

{
    "location": "man/SA/move_generators.html#Mapper2.SA.CachedMoveGenerator",
    "page": "Move Generators",
    "title": "Mapper2.SA.CachedMoveGenerator",
    "category": "type",
    "text": "mutable struct CachedMoveGenerator{T} <: Mapper2.SA.MoveGenerator\n\nFields\n\nmoves\n\nDocumentation\n\nThis move generator precomputes all of the valid moves for each class at all addresses, and references this cached database to generator moves.\n\nStandard classes are used to index into the first level of moves. The inner dictionary is a mapping from a base address to a MoveLUT for that address.\n\nMethod List\n\nCachedMoveGenerator(sa_struct)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/MoveGenerators.jl:142.\n\n\n\n\n\n"
},

{
    "location": "man/SA/move_generators.html#Mapper2.SA.MoveLUT",
    "page": "Move Generators",
    "title": "Mapper2.SA.MoveLUT",
    "category": "type",
    "text": "mutable struct MoveLUT{T}\n\nFields\n\ntargets\nVector of destination addresses from the base address. Sorted in increasing order of distance from the base addresses according to the distance metric of the parent SAStruct.\n\nidx\nThe index of the last entry in targets that is within the current move distance limit of the base address.\n\nindices\nCached idx for various move distance limits.\n\nDocumentation\n\nLook-up table for moves for a single node class starting at some base address.\n\nThe main invariant of this a MoveLUT L is with base address alpha is\n\ntextdistanceleft( L_texttargetsi - alpha right) leq delta\n     forall i in 1 ldots L_textidx\n\nwhere textdistance is the distance between to addresses in the SAStruct and \\delta is the current move distance limit.\n\nThus, to generate a random move within delta of alpha, we must need to perform the operation\n\nL.targets[rand(1:L.idx)]\n\nassuming L.idx has been configured correctly.\n\nTo aid in the configuration of L.idx, the field indices is constructed such that for a move limit delta, L.idx = L.indices[δ].\n\nMethod List\n\nMoveLUT(targets, idx, indices)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/MoveGenerators.jl:102.\n\n\n\n\n\n"
},

{
    "location": "man/SA/move_generators.html#Cached-Move-Generator-1",
    "page": "Move Generators",
    "title": "Cached Move Generator",
    "category": "section",
    "text": "SA.CachedMoveGenerator\nSA.MoveLUT"
},

{
    "location": "man/SA/move_generators.html#Search-Move-Generator-1",
    "page": "Move Generators",
    "title": "Search Move Generator",
    "category": "section",
    "text": "SA.SearchMoveGenerator"
},

{
    "location": "man/SA/map_tables.html#",
    "page": "MapTables",
    "title": "MapTables",
    "category": "page",
    "text": ""
},

{
    "location": "man/SA/map_tables.html#Mapper2.SA.AbstractMapTable",
    "page": "MapTables",
    "title": "Mapper2.SA.AbstractMapTable",
    "category": "type",
    "text": "abstract type AbstractMapTable\n\nFields\n\nDocumentation\n\nTODO\n\nAPI\n\nlocation_type\ngetlocations\nisvalid\n\nImplementations\n\nMapTable\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/SA/map_tables.html#MapTables-1",
    "page": "MapTables",
    "title": "MapTables",
    "category": "section",
    "text": "SA.AbstractMapTable"
},

{
    "location": "man/SA/map_tables.html#Mapper2.SA.location_type",
    "page": "MapTables",
    "title": "Mapper2.SA.location_type",
    "category": "function",
    "text": "Return the stored location type for a MapTable.\n\nMethod List\n\nlocation_type(?)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/MapTables.jl:96.\n\n\n\n\n\n"
},

{
    "location": "man/SA/map_tables.html#Mapper2.SA.getlocations",
    "page": "MapTables",
    "title": "Mapper2.SA.getlocations",
    "category": "function",
    "text": "getlocations(maptable, class::Int)\n\nReturn a vector of locations that nodes of type class can occupy.\n\nMethod List\n\ngetlocations(maptable, class)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/MapTables.jl:102.\n\n\n\n\n\n"
},

{
    "location": "man/SA/map_tables.html#Mapper2.SA.isvalid",
    "page": "MapTables",
    "title": "Mapper2.SA.isvalid",
    "category": "function",
    "text": "isvalid(maptable, class, address :: Address)\n\nReturn true if nodes of type class can occupy address. In other words, there is some component at adddress that class can be mapped to.\n\nMethod List\n\nisvalid(maptable, class, address)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/MapTables.jl:111.\n\n\n\n\n\n"
},

{
    "location": "man/SA/map_tables.html#API-1",
    "page": "MapTables",
    "title": "API",
    "category": "section",
    "text": "SA.location_type\nSA.getlocations\nSA.isvalid"
},

{
    "location": "man/SA/map_tables.html#Mapper2.SA.MapTable",
    "page": "MapTables",
    "title": "Mapper2.SA.MapTable",
    "category": "type",
    "text": "struct MapTable{D} <: Mapper2.SA.AbstractMapTable\n\nFields\n\nmask\nBit mask of whether a node class may be mapped to an address.\nAccessing strategy: Look up the node class to index the outer vector. Index the inner array with an address.\nA true entry means the task class can be mapped. A false entry means the task calss cannot be mapped.\n\nDocumentation\n\nDefault implementation of AbstractMapTable\n\nParameters:\n\nD - The dimensionality of the Addresses in the table.\n\nMethod List\n\nMapTable(mask)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/MapTables.jl:67.\n\nMapTable(toplevel, ruleset, equivalence_classes, pathtable)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Place/SA/MapTables.jl:89.\n\n\n\n\n\n"
},

{
    "location": "man/SA/map_tables.html#Implementations-1",
    "page": "MapTables",
    "title": "Implementations",
    "category": "section",
    "text": "SA.MapTable"
},

{
    "location": "man/routing/routing.html#",
    "page": "Routing",
    "title": "Routing",
    "category": "page",
    "text": ""
},

{
    "location": "man/routing/routing.html#Mapper2.Routing.route!",
    "page": "Routing",
    "title": "Mapper2.Routing.route!",
    "category": "function",
    "text": "route!(map::Map; meta_prefix = \"\")\n\nRun pathfinder routing directly on map. Keyword argument meta_prefix allows controlling the prefix of the map.metadata keys generated below.\n\nRecords the following metrics into map.metadata:\n\nrouting_struct_time - Time it took to build the RoutingStruct\nrouting_struct_bytes - Memory allocation to build RoutingStruct\nrouting_passed :: Bool - true if routing passes check_routing,   otherwise false.\nrouting_error :: Bool - true if routing experienced a connectivity error.\n\nThe following are also included if routing_error == false.\n\nrouting_time - Time to run routing.\nrouting_bytes - Memory allocation during routing.\nrouting_global_links - The number of global links used in the final routing.\n\n\n\n\n\n"
},

{
    "location": "man/routing/routing.html#Routing-1",
    "page": "Routing",
    "title": "Routing",
    "category": "section",
    "text": "Routing.route!"
},

{
    "location": "man/routing/routing.html#Mapper2.Routing.routing_channel",
    "page": "Routing",
    "title": "Mapper2.Routing.routing_channel",
    "category": "function",
    "text": "routing_channel(ruleset::RuleSet, start, stop, edge::TaskgraphEdge)\n\nReturn <:RoutingChannel for edge. Arguments start and stop are return elements for start_vertices and stop_vertices respectively.\n\n\n\n\n\n"
},

{
    "location": "man/routing/routing.html#Methods-to-Extend-1",
    "page": "Routing",
    "title": "Methods to Extend",
    "category": "section",
    "text": "Routing.routing_channel"
},

{
    "location": "man/routing/struct.html#",
    "page": "Routing Struct",
    "title": "Routing Struct",
    "category": "page",
    "text": ""
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.RoutingStruct",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.RoutingStruct",
    "category": "type",
    "text": "struct RoutingStruct{L<:RoutingLink, C<:RoutingChannel}\n\nFields\n\narchitecture_graph\nBase RoutingGraph for the underlying routing architecture.\ngraph_vertex_annotations\nAnnotating RoutingLink for each routing element in architecture_graph.\n\nroutings\nGraphs of routing resources used by each channel.\n\nchannels\nVector{RoutingChannel} containing the channel information for the taskgraph.\n\nchannel_index_to_taskgraph_index\nConvenience structure mapping local channel indices back to edge indices in the parent taskgraph.\n\nDocumentation\n\nCentral type for routing. Not meant for extending.\n\nAPI\n\nallroutes\ngetroute\nalllinks\ngetlink\nstart_vertices\nstop_vertices\ngetchannel\ngetmap\ngetgraph\niscongested\nclear_route\nsetroute\n\nMethod List\n\nRoutingStruct(architecture_graph, graph_vertex_annotations, routings, channels, channel_index_to_taskgraph_index)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Struct.jl:20.\n\nRoutingStruct(map)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Struct.jl:49.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Routing-Struct-1",
    "page": "Routing Struct",
    "title": "Routing Struct",
    "category": "section",
    "text": "The Routing Struct is the central datatype for routing, encoding connectivity information of the ports, links, and other routing resources of the  architecture. Furthermore, it encodes which links may be used by which channels in the Taskgraph and the valid starting and ending ports for each channel.Routing.RoutingStruct"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.allroutes",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.allroutes",
    "category": "function",
    "text": "allroutes(routing_struct)\n\n\nReturn all routings in routing_struct.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.getroute",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.getroute",
    "category": "function",
    "text": "getroute(routing_struct, index)\n\n\nReturn route for channel index.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.alllinks",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.alllinks",
    "category": "function",
    "text": "alllinks(routing_struct)\n\n\nReturn Vector{RoutingLink} for all links in `routing_struct.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.getlink",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.getlink",
    "category": "function",
    "text": "getlink(routing_struct, i)\n\n\nReturn <:RoutingLink for link in routing_struct with indes i.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.start_vertices",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.start_vertices",
    "category": "function",
    "text": "start_vertices(routing_struct, i)\n\n\nReturn Vector{PortVertices} of start vertices for channel index i.\n\nstart_vertices(channel::RoutingChannel) :: Vector{PortVertices}\n\nReturn Vector{PortVertices} of start vertices for channel.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.stop_vertices",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.stop_vertices",
    "category": "function",
    "text": "stop_vertices(routing_struct, i)\n\n\nReturn Vector{PortVertices} of stop vertices for channel index i.\n\nstop_vertices(channel::RoutingChannel) :: Vector{PortVertices}\n\nReturn Vector{PortVertices} of stop vertices for channel.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.getchannel",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.getchannel",
    "category": "function",
    "text": "getchannel(routing_struct, i)\n\n\nReturn <:RoutingChannel with indesx i.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.getgraph",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.getgraph",
    "category": "function",
    "text": "getgraph(routing_struct)\n\n\nReturn the RoutingGraph member of routing_struct.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.iscongested",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.iscongested",
    "category": "function",
    "text": "iscongested(routing_struct, [path])\n\nReturn true if routing congestion exists in routing_struct. If path is given either as a ChannelIndex or SparseDiGraph, return true if just the specified path is congested.\n\nMethod List\n\niscongested(routing_struct)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Struct.jl:155.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.clear_route",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.clear_route",
    "category": "function",
    "text": "clear_route(rs::RoutingStruct, channel::ChannelIndex)\n\nRip up the current routing for the given link.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#Mapper2.Routing.setroute",
    "page": "Routing Struct",
    "title": "Mapper2.Routing.setroute",
    "category": "function",
    "text": "setroute(routing_struct, route, channel)\n\n\nAssign route to channel.\n\n\n\n\n\n"
},

{
    "location": "man/routing/struct.html#API-1",
    "page": "Routing Struct",
    "title": "API",
    "category": "section",
    "text": "Routing.allroutes\nRouting.getroute\nRouting.alllinks\nRouting.getlink\nRouting.start_vertices\nRouting.stop_vertices\nRouting.getchannel\nRouting.getgraph\nRouting.iscongested\nRouting.clear_route\nRouting.setroute"
},

{
    "location": "man/routing/links.html#",
    "page": "Routing Links",
    "title": "Routing Links",
    "category": "page",
    "text": ""
},

{
    "location": "man/routing/links.html#Mapper2.Routing.RoutingLink",
    "page": "Routing Links",
    "title": "Mapper2.Routing.RoutingLink",
    "category": "type",
    "text": "abstract type RoutingLink\n\nFields\n\nDocumentation\n\nRepresentation of routing resources in an architecture.\n\nAPI\n\nchannels\ncost\ncapacity\noccupancy\naddchannel\nremchannel\n\nImplementations\n\nBasicRoutingLink - Reference this type for what methods of the API   come for free when using various fields of the basic type.\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/routing/links.html#Routing-Links-1",
    "page": "Routing Links",
    "title": "Routing Links",
    "category": "section",
    "text": "The central type to represent routing resources during routing.Routing.RoutingLink"
},

{
    "location": "man/routing/links.html#Mapper2.Routing.channels",
    "page": "Routing Links",
    "title": "Mapper2.Routing.channels",
    "category": "function",
    "text": "channels(link::RoutingLink) :: Vector{ChannelIndex}\n\nReturn list of channels currently occupying link.\n\n\n\n\n\n"
},

{
    "location": "man/routing/links.html#Mapper2.Routing.cost",
    "page": "Routing Links",
    "title": "Mapper2.Routing.cost",
    "category": "function",
    "text": "cost(link::RoutingLink) :: Float64\n\nReturn the base cost of a channel using link as a routing resource.\n\n\n\n\n\n"
},

{
    "location": "man/routing/links.html#Mapper2.Routing.capacity",
    "page": "Routing Links",
    "title": "Mapper2.Routing.capacity",
    "category": "function",
    "text": "capacity(link::RoutingLink) :: Real\n\nReturn the capacity of link.\n\n\n\n\n\n"
},

{
    "location": "man/routing/links.html#Mapper2.Routing.occupancy",
    "page": "Routing Links",
    "title": "Mapper2.Routing.occupancy",
    "category": "function",
    "text": "occupancy(link::RoutingLink)\n\nReturn the number of channels currently using link.\n\n\n\n\n\n"
},

{
    "location": "man/routing/links.html#Mapper2.Routing.addchannel",
    "page": "Routing Links",
    "title": "Mapper2.Routing.addchannel",
    "category": "function",
    "text": "addchannel(link::RoutingLink, channel::ChannelIndex)\n\nRecord that channel is using link.\n\n\n\n\n\n"
},

{
    "location": "man/routing/links.html#Mapper2.Routing.remchannel",
    "page": "Routing Links",
    "title": "Mapper2.Routing.remchannel",
    "category": "function",
    "text": "remchannel(link::RoutingLink, channel::ChannelIndex)\n\nRemove channel from the list of channels using link.\n\n\n\n\n\n"
},

{
    "location": "man/routing/links.html#API-1",
    "page": "Routing Links",
    "title": "API",
    "category": "section",
    "text": "Routing.channels\nRouting.cost\nRouting.capacity\nRouting.occupancy\nRouting.addchannel\nRouting.remchannel"
},

{
    "location": "man/routing/links.html#Mapper2.Routing.BasicRoutingLink",
    "page": "Routing Links",
    "title": "Mapper2.Routing.BasicRoutingLink",
    "category": "type",
    "text": "struct BasicRoutingLink <: RoutingLink\n\nFields\n\nchannels\nVector of channels curently assigned to the link.\ncost\nBase cost of using this link.\ncapacity\nNumber of channels that can be mapped to this link without it being considered congested.\n\nDocumentation\n\nDefault implementation of RoutingLink\n\nSimple container for channel indices, cost, and capacity.\n\nConstructors\n\nBasicRoutingLink(channels, cost, capacity)\nBasicRoutingLink(channels, cost, capacity)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Links.jl:12.\n\nBasicRoutingLink(; cost, capacity)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Links.jl:24.\n\nMethod List\n\nBasicRoutingLink(channels, cost, capacity)\nBasicRoutingLink(channels, cost, capacity)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Links.jl:12.\n\nBasicRoutingLink(; cost, capacity)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Links.jl:24.\n\n\n\n\n\n"
},

{
    "location": "man/routing/links.html#Implementations-1",
    "page": "Routing Links",
    "title": "Implementations",
    "category": "section",
    "text": "Routing.BasicRoutingLink"
},

{
    "location": "man/routing/channels.html#",
    "page": "Routing Channels",
    "title": "Routing Channels",
    "category": "page",
    "text": ""
},

{
    "location": "man/routing/channels.html#Mapper2.Routing.RoutingChannel",
    "page": "Routing Channels",
    "title": "Mapper2.Routing.RoutingChannel",
    "category": "type",
    "text": "abstract type RoutingChannel\n\nFields\n\nDocumentation\n\nRepresentation of channels in the taskgraph for routing.\n\nAPI\n\nstart_vertices\nstop_vertices\nisless(a::RoutingChannel, b::RoutingChannel)\n\nImplementations\n\nBasicChannel\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/routing/channels.html#Routing-Channels-1",
    "page": "Routing Channels",
    "title": "Routing Channels",
    "category": "section",
    "text": "Routing.RoutingChannel"
},

{
    "location": "man/routing/channels.html#Base.isless-Tuple{RoutingChannel,RoutingChannel}",
    "page": "Routing Channels",
    "title": "Base.isless",
    "category": "method",
    "text": "isless(a::RoutingChannel, b::RoutingChannel) :: Bool\n\nReturn true if a should be routed before b.\n\n\n\n\n\n"
},

{
    "location": "man/routing/channels.html#API-1",
    "page": "Routing Channels",
    "title": "API",
    "category": "section",
    "text": "Routing.isless(::Routing.RoutingChannel, ::Routing.RoutingChannel)"
},

{
    "location": "man/routing/channels.html#Mapper2.Routing.BasicChannel",
    "page": "Routing Channels",
    "title": "Mapper2.Routing.BasicChannel",
    "category": "type",
    "text": "struct BasicChannel <: RoutingChannel\n\nFields\n\nstart_vertices\nDirect storage for the Vector{PortVertices} of the sets of start vertices for each source of the channel.\n\nstop_vertices\nDirect storage for the Vector{PortVertices} of the sets of stop vertices for each source of the channel.\n\nDocumentation\n\nDefault implementation of RoutingChannel.\n\nMethod List\n\nBasicChannel(start_vertices, stop_vertices)\nBasicChannel(start_vertices, stop_vertices)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Channels.jl:5.\n\n\n\n\n\n"
},

{
    "location": "man/routing/channels.html#Implementations-1",
    "page": "Routing Channels",
    "title": "Implementations",
    "category": "section",
    "text": "Routing.BasicChannel"
},

{
    "location": "man/routing/channels.html#Mapper2.Routing.ChannelIndex",
    "page": "Routing Channels",
    "title": "Mapper2.Routing.ChannelIndex",
    "category": "type",
    "text": "struct ChannelIndex\n\nFields\n\nidx\n\nDocumentation\n\nType to access channels in the routing taskgraph. Essentially, it is just a  wrapper for an integer, but typed to allow safer and clearer usage.\n\nMethod List\n\nChannelIndex(idx)\nChannelIndex(idx)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Types.jl:8.\n\n\n\n\n\n"
},

{
    "location": "man/routing/channels.html#Mapper2.Routing.PortVertices",
    "page": "Routing Channels",
    "title": "Mapper2.Routing.PortVertices",
    "category": "type",
    "text": "struct PortVertices\n\nFields\n\nindices\n\nDocumentation\n\nIndices of a RoutingGraph that can serve as either start or stop vertices (depending on the context) of one branch of a RoutingChannel.\n\nMethod List\n\nPortVertices(indices)\nPortVertices(indices)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Types.jl:19.\n\n\n\n\n\n"
},

{
    "location": "man/routing/channels.html#Helpful-Types-1",
    "page": "Routing Channels",
    "title": "Helpful Types",
    "category": "section",
    "text": "Routing.ChannelIndex\nRouting.PortVertices"
},

{
    "location": "man/routing/graph.html#",
    "page": "Routing Graph",
    "title": "Routing Graph",
    "category": "page",
    "text": ""
},

{
    "location": "man/routing/graph.html#Mapper2.Routing.RoutingGraph",
    "page": "Routing Graph",
    "title": "Mapper2.Routing.RoutingGraph",
    "category": "type",
    "text": "struct RoutingGraph\n\nFields\n\ngraph\nAdjacency information of routing resources, encode as a LightGraphs.SimpleDiGraph.\n\nmap\nTranslation information mapping elements on the parent TopLevel to indices in graph.\nImplemented as a Dict{Path{<:Union{Port,Link,Component}}, Int64} where the values in the dict are the vertex index in graph of the key.\n\nDocumentation\n\nRepresentation of the routing resources of a TopLevel.\n\nMethod List\n\nRoutingGraph(graph, map)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Graph.jl:26.\n\n\n\n\n\n"
},

{
    "location": "man/routing/graph.html#Mapper2.Routing.getmap",
    "page": "Routing Graph",
    "title": "Mapper2.Routing.getmap",
    "category": "function",
    "text": "Return the map of a RoutingGraph\n\nMethod List\n\ngetmap(graph)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/Route/Graph.jl:44.\n\n\n\n\n\n"
},

{
    "location": "man/routing/graph.html#Routing-Graph-1",
    "page": "Routing Graph",
    "title": "Routing Graph",
    "category": "section",
    "text": "Routing.RoutingGraph\nRouting.getmap"
},

{
    "location": "man/mappergraphs.html#",
    "page": "MapperGraphs",
    "title": "MapperGraphs",
    "category": "page",
    "text": ""
},

{
    "location": "man/mappergraphs.html#Mapper2.MapperGraphs.SparseDiGraph",
    "page": "MapperGraphs",
    "title": "Mapper2.MapperGraphs.SparseDiGraph",
    "category": "type",
    "text": "struct SparseDiGraph{T}\n\nFields\n\nvertices\n\nDocumentation\n\nGraph representation with arbitrary vertices of type T.\n\nMethod List\n\nSparseDiGraph(vertices)\n\ndefined at /home/travis/build/hildebrandmw/Mapper2.jl/src/MapperGraphs.jl:56.\n\n\n\n\n\n"
},

{
    "location": "man/mappergraphs.html#MapperGraphs-1",
    "page": "MapperGraphs",
    "title": "MapperGraphs",
    "category": "section",
    "text": "Mapper2.MapperGraphs.SparseDiGraph"
},

{
    "location": "man/mappergraphs.html#Mapper2.MapperGraphs.source_vertices",
    "page": "MapperGraphs",
    "title": "Mapper2.MapperGraphs.source_vertices",
    "category": "function",
    "text": "source_vertices(graph::SparseDiGraph{T}) :: Vector{T} where T\n\nReturn the vertices of graph that have no incoming edges.\n\n\n\n\n\n"
},

{
    "location": "man/mappergraphs.html#Mapper2.MapperGraphs.sink_vertices",
    "page": "MapperGraphs",
    "title": "Mapper2.MapperGraphs.sink_vertices",
    "category": "function",
    "text": "sink_vertices(graph::SparseDiGraph{T}) :: Vector{T} where T\n\nReturn the vertices of graph that have no outgoing edges.\n\n\n\n\n\n"
},

{
    "location": "man/mappergraphs.html#Mapper2.MapperGraphs.make_lightgraph",
    "page": "MapperGraphs",
    "title": "Mapper2.MapperGraphs.make_lightgraph",
    "category": "function",
    "text": "make_lightgraph(graph::SparseDiGraph{T}) where T :: (SimpleDiGraph, Dict{T,Int})\n\nReturn tuple (g, d) where g :: SimpleDiGraph is a LightGraph ismorphic to graph and d maps vertices of graph to vertices of g.\n\n\n\n\n\n"
},

{
    "location": "man/mappergraphs.html#Mapper2.MapperGraphs.linearize",
    "page": "MapperGraphs",
    "title": "Mapper2.MapperGraphs.linearize",
    "category": "function",
    "text": "linearize(graph::SparseDiGraph{T}) where T\n\nReturn a Vector{T} of vertices of graph in linearized traversal order if  graph is linear. Throw error if ggraph is not a linear graph.\n\n\n\n\n\n"
},

{
    "location": "man/mappergraphs.html#Special-Methods-for-[SparseDiGraph](@ref-Mapper2.MapperGraphs.SparseDiGraph)-1",
    "page": "MapperGraphs",
    "title": "Special Methods for SparseDiGraph",
    "category": "section",
    "text": "Mapper2.MapperGraphs.source_vertices\nMapper2.MapperGraphs.sink_vertices\nMapper2.MapperGraphs.make_lightgraph\nMapper2.MapperGraphs.linearize"
},

{
    "location": "man/helper.html#",
    "page": "Helper Functions",
    "title": "Helper Functions",
    "category": "page",
    "text": ""
},

{
    "location": "man/helper.html#Mapper2.Helper.add_to_dict",
    "page": "Helper Functions",
    "title": "Mapper2.Helper.add_to_dict",
    "category": "function",
    "text": "add_to_dict(d::Dict{K}, k::K, v = 1; b = 1) where K\n\nIncrement d[k] by v. If d[k] does not exist, initialize d[k] = b.\n\n\n\n\n\n"
},

{
    "location": "man/helper.html#Mapper2.Helper.dim_min",
    "page": "Helper Functions",
    "title": "Mapper2.Helper.dim_min",
    "category": "function",
    "text": "dim_min(indices) returns tuple of the minimum componentwise values from a collection of CartesianIndices.\n\n\n\n\n\n"
},

{
    "location": "man/helper.html#Mapper2.Helper.dim_max",
    "page": "Helper Functions",
    "title": "Mapper2.Helper.dim_max",
    "category": "function",
    "text": "dim_max(indices) returns tuple of the minimum componentwise values from a collection of CartesianIndices.\n\n\n\n\n\n"
},

{
    "location": "man/helper.html#Mapper2.Helper.emptymeta",
    "page": "Helper Functions",
    "title": "Mapper2.Helper.emptymeta",
    "category": "function",
    "text": "Return an empty Dict{String,Any}() for metadata fields.\n\n\n\n\n\n"
},

{
    "location": "man/helper.html#Mapper2.Helper.intern",
    "page": "Helper Functions",
    "title": "Mapper2.Helper.intern",
    "category": "function",
    "text": "intern(x)\n\nGiven a mutable collection x, make all equivalent values in x point to a single instance in memory. If x is made up of many of the same arrays, this can greatly decrease the amount of memory required to store x.\n\n\n\n\n\n"
},

{
    "location": "man/helper.html#Mapper2.Helper.push_to_dict",
    "page": "Helper Functions",
    "title": "Mapper2.Helper.push_to_dict",
    "category": "function",
    "text": "push_to_dict(d, k, v)\n\nPush value v to the vector found in dictionary d at d[k]. If d[k] does not exist, create a new vector by d[k] = [v].\n\n\n\n\n\n"
},

{
    "location": "man/helper.html#Mapper2.Helper.rev_dict",
    "page": "Helper Functions",
    "title": "Mapper2.Helper.rev_dict",
    "category": "function",
    "text": "rev_dict(d)\n\nReverse the keys and values of dictionary d. Behavior if multiple values are equivalent is not defined.\n\n\n\n\n\n"
},

{
    "location": "man/helper.html#Mapper2.Helper.rev_dict_safe",
    "page": "Helper Functions",
    "title": "Mapper2.Helper.rev_dict_safe",
    "category": "function",
    "text": "rev_dict_safe(d::Dict{K,V}) where {K,V}\n\nReverse the keys and values of dictionary d. Returns a dictionary of type Dict{V, Vector{K}} to handle the case where the same value in d points to multiple keys.\n\n\n\n\n\n"
},

{
    "location": "man/helper.html#Helper-Functions-1",
    "page": "Helper Functions",
    "title": "Helper Functions",
    "category": "section",
    "text": "Helper.jl contains some helpfer functions that are used throughout the Mapper.Mapper2.Helper.add_to_dict\nMapper2.Helper.dim_min\nMapper2.Helper.dim_max\nMapper2.Helper.emptymeta\nMapper2.Helper.intern\nMapper2.Helper.push_to_dict\nMapper2.Helper.rev_dict\nMapper2.Helper.rev_dict_safe"
},

{
    "location": "man/paths.html#",
    "page": "Paths",
    "title": "Paths",
    "category": "page",
    "text": ""
},

{
    "location": "man/paths.html#Mapper2.MapperCore.Path",
    "page": "Paths",
    "title": "Mapper2.MapperCore.Path",
    "category": "type",
    "text": "struct Path{T}\n\nFields\n\nsteps\n\nDocumentation\n\nTyped wrapper for Vector{String}.\n\nMethod List\n\n\n\n\n\n"
},

{
    "location": "man/paths.html#Paths-1",
    "page": "Paths",
    "title": "Paths",
    "category": "section",
    "text": "Paths serve as location references for architectural components in a  TopLevel or Component.MapperCore.Path"
},

]}
