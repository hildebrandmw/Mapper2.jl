#=
Authors:
    Mark Hildebrand

This defines the basic architecture data types and methods that define an
architecture model. We define a master class "AbstractComponent". From that,
we define concrete "Components".

STRUCTURE

These components will represent functional units of an architecture. For example,
in the case of KiloCore, these could represent the actual processors, routing
muxes, packet routers etc. Components will be hierarchical. Each component
will keep track of its children, and its parent. One constraint is that
all child components must be the same concrete sub-type of AbstractComponent
in order to satisfy Julia's requirement of type stability.

METADATA

Each component will have a meta-data dictionary that will accept string keys
and return the corresponding component. This will allow storage of things
like attributes supplied (as an array of strings), or the number of writes
done by a processor etc.

NOTE: Initially, this will be a
dictionary of type Dict{String, Any}. This is a bit dangerous because of the
type ambiguity, but hopefully this will not have to be referenced that often,
of it it does have to be referenced often will be accelerated externally. If
this causes performance problems in the future, we'll have to revisit it and
see if we can bring performance up.

PRIMITIVE IDENTIFIERS

Further, each component will a string identifier to its primitive type. (If
a primitive type is undeclared, a null string will be used). For example,
primitives like multiplexors will have special methods for building a routing
graph and dumping configuration information post-routing.

COMPONENT NAMES

Each component will also have a name (if no name is supplied, a default will
be supplied). Names of sub-components will be recorded by a parent. Sub
conponents can be accesses using "dot" notation. For example, if the top
level is "arch", it has a sub componend "tile1" which has a sub component
"mux0", the component "mux0" can be accessed from the parent using the
string "arch.tile1.mux0".

PORTS

Components will also have ports which can be connected using links.
Ports will have adjacency lists to record the other ports to which they
are connected. For simplicity, ports may only be connected to other ports
at the same level of hierarchy. Otherwise, it would be way too complicated
to keep track of everything.

Complementary dictionaries in each port will record information about the link,
such as the capacity, cost, and other metrics that people may find relevant
to include with the link.

TOPLEVEL

The top level will be an TopLevel component, which will still behave
like a normal component, but also have the ability to assign addresses
to sub components and will be used as the top level architecture
=#

################################################################################
#                                  PATH TYPES                                  #
################################################################################
#=
These path types will be used to easily access ports, links,  and sub-components
in a given hierarchy.

The general hierarchy is as follows:

At the top is the abstract type "AbstractPath". This further subtypes into
"AbstractComponentPath" types. Subtypes of AbstractComponentPath are expected
to be paths from some top level component down to a sub component. Since each
instantiated component inside a component has a unique instance ID, a standard
component path is simply an array of strings where each entry is the instance
name of a subcomponent. 

AbstractComponentPath come in two flavors: 

    - ComponentPath: where the expected toplevel component is a "Component"
        type.
    - AddressPath: where the expected toplevel component is a "TopLevel". 
        In this case, the key to access subcomponents is an Address. Thus,
        AddressPaths can be thought of as a collection where the first item
        is a Address and the rest of the items are strings like a normal
        ComponentPath.

        NOTE: AddressPaths are parameterized on their dimensions to allow for
        type-stable code.


--- PortPath and LinkPath ---

There are other path type variables whose concrete instances subtype directly
from AbstractPath. These are PortPath and LinkPath types. These are used to
specify ports and links in much the same way that ComponentPaths are used to
specify components in the hierarchy. 

This is done by using a component path to select the correct component, and then
using a string identifier to select the correct port/link. 

These types are pamaterized by whether this underlying component path is a
ComponentPath or an AddressPath.
=#

module Architecture

using ..Mapper2: Addresses, Helper
using IterTools
using MicroLogging

export  AbstractArchitecture,
        # Path Types
        AbstractPath,
        AbstractComponentPath,
        ComponentPath,
        AddressPath,
        PortPath,
        LinkPath,
        # Path Methods
        istop,
        prefix,
        push,
        pushfirst,
        typestring,
        # Architecture stuff
        AbstractPort,
        Port,
        Link,
        PORT_SINKS,
        PORT_SOURCES,
        # Link Methods
        isaddresslink,
        # Components
        AbstractComponent,
        TopLevel,
        Component,
        # Methods
        ports,
        architecture,
        addresses,
        pathtype,
        children,
        walk_children,
        connected_components,
        search_metadata,
        search_metadata!,
        check_connectivity,
        get_connected_port,
        isfree,
        isgloballink,
        isglobalport,
        # Asserts
        assert_no_children,
        assert_no_intrarouting,
        # Constructor Types
        OffsetRule,
        PortRule,
        # Constructor Functions
        add_port,
        add_child,
        connect_ports,
        connection_rule,
        build_mux,
        check

# File containing architecture model definitions
include("Model.jl")
# File containing constructor functions for the TopLevel
include("Constructors.jl")
include("Check.jl")

end # module Architecture
