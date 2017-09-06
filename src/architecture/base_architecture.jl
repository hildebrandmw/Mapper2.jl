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

Each component will also have a name (if no name is supplied, a default will
be supplied). Names of sub-components will be recorded by a parent. Sub
conponents can be accesses using "dot" notation. For example, if the top
level is "arch", it has a sub componend "tile1" which has a sub component
"mux0", the component "mux0" can be accessed from the parent using the
string "arch.tile1.mux0".

Components will also have ports which can be connected using links.
TODO: Think about how this will work out more clearly.

The top level will be an TopLevel component, which will still behave
like a normal component, but also have the ability to assign addresses
to sub components and will be used as the top level architecture

NOTATION

Some accessor functions will have two versions, one that is called only on the
present Component, and one that will be recursively called on the component
and each sub-component. In these cases, the function that works recusrively
will end in an exclamation point "!".
=#



################################################################################
#                               COMPONENT TYPES                                #
################################################################################

# Master abstract type from which all component types will subtype
abstract type AbstractComponent end

#=
TODO: Think about how ports and links are going to work.
=#
#=
When creating components from the ground up, we might not know the type of
the parent immediately. An OrphanComponent will be used to build up a component
until the type of its parent is known. Then, a component can be created
from the orphan component and the parent.
=#
mutable struct OrphanCompnent <: AbstractComponent
    """The declared name of this component"""
    name    ::String

    """
    Dictionary of all children of this component. String keys will be the
    instance names of the component.
    """
    children::Dict{String, Component}
    metadata::Dict{String, Any}
    #ports
    #links


    # Constructor
    """
        OrphanComponent(name, children = Component[], metadata = Dict{String, Any}())

    Return an orphan component with the given name. Can construct with the
    given `children` and `metadata`, otherwise those fields will be empty.
    """
    function OrphanComponent(name, children = Dict{String, Any}(), metadata = Dict{String, Any}())
        return new(
            name,
            children,
            metadata
        )
    end
end




mutable struct Component <: AbstractComponent
    """The declared name of this component"""
    name    ::String

    """Parent of the current component"""
    parent  ::Component

    """
    Dictionary of all children of this component. String keys will be the
    instance names of the component.
    """
    children::Dict{String, Component}
    metadata::Dict{String, Any}
    #ports
    #links

    # Constructor
    """
        Component(name, parent, children = Component[], metadata = Dict{String, Any}())

    Return an orphan component with the given name. Can construct with the
    given `children` and `metadata`, otherwise those fields will be empty.
    """
    function Component( name,
                        parent::Component,
                        children = Dict{String, Any}(),
                        metadata = Dict{String, Any}()
                    )
        return new(
            name,
            parent,
            children,
            metadata
        )
    end
end
