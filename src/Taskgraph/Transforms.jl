#=
Several transforms will have to be applied to the taskgraph after it is initially
parsed depending on the options selected by at the top level.

The TaskgraphTransform type will allow these to be ordered and ensure that
all transforms are executed.

NOTE: Each TaskgraphTransform has a set of other TaskgraphTransform types
as a field. These are the TaskgraphTransforms that must be executed before
this transform is run. This list need not be exhaustive - it can just be
transforms that must be immediately run before and not the transforms that
those depend on. All of that will be figured out in the `apply_transforms`
function.

This approach means that if there is a circular reference of transforms, Julia
will eventually stack overflow with this endless cycle of creation.

While this is not the most elegant approach to handling the circular reference
problem, it will work for now and could lead to some fun times.
=#
struct TaskgraphTransform
    name::String
    "Name of the transforms that this transform depends on."
    requires::Set{TaskgraphTransform}
    "Pointer to the function that executes this transform."
    transform    ::Function
end

import Base.==
==(a::TaskgraphTransform, b::TaskgraphTransform) = a.name == b.name

"""
    run_transform(tg::Taskgraph, transform::TaskgraphTransform)

Run the transform specified by the `TaskgraphTransform` type.
"""
function run_transform(tg::Taskgraph, transform::TaskgraphTransform)::Taskgraph
    return tg = transform.transform(tg)::Taskgraph
end

function apply_transforms(tg, transform_list)
    # First, make sure transforms have all of their dependencies. Keep iterting
    # through the set until everything is satisfied.
    transform_set = OrderedSet(transform_list)
    was_change = true
    while was_change
        # Set was_change to 'false'. If there's a change, this will be set back
        # to 'true' for another iteration.
        was_change = false
        # original size of the transform set to see if it grew.
        original_set_size = length(transform_set)
        #=
        What this does is go through each transform in the set and add all the
        required transforms to the set. Since sets can only have one of any
        given element, if a transform is already in the set, nothing will change.

        There are two branchs:

        1. The length of the set does not change. Then all required transforms
            are in the set and we can exit.

        2. The length of the set does change. Then that means more transforms
            were added to the set and we do the analysis again.
        =#
        for transform in copy(transform_set)
            if length(transform.requires) > 0
                push!(transform_set, transform.requires...)  
            end
        end
        if length(transform_set) > original_set_size
            was_change = true
        end
    end
    # Sort the resulting set and then run all the transforms.
    for t in transform_set
        println(t)
    end
    println("")
    ordered_transforms = sort_transforms(transform_set) 
    println(ordered_transforms)
    for transform in ordered_transforms
        if DEBUG
            print_with_color(:yellow, "Applying Transform: ", 
                             string(transform.transform), "\n")
        end
        tg = run_transform(tg, transform)
    end
    return tg
end

#=
Normal sorting won't work - need to have a slightly different method to
handle the partial orderings.
=#
function sort_transforms(transforms)
    #=
    We can assume that all dependencies for each transform live in the
    transforms set. What we do is:

    1. Initialize an array to store the sorted transforms.
    2. Iterate through the TaskgraphTransform list. If none of its dependencies
        are in the transforms set, then they've all been added to the list and
        we can add the transform to the sorted array
    3. Otherwise, move on to the next transform.
    4. Iterate until all transforms are sorted.
    =#
    ordered_transforms = Array{eltype(transforms),1}(length(transforms))
    i = 1
    while length(transforms) > 0
        # Iterate through the transforms
        for transform in transforms
            # Check if any of the transform's dependencies are in the set
            can_add = true
            for dependancy in transform.requires
                if in(dependancy, transforms)
                    can_add = false
                    break
                end
            end
            if can_add
                ordered_transforms[i] = transform
                i += 1
                delete!(transforms, transform)
                break
            end
        end
    end
    return ordered_transforms
end
