function report_routing_stats(m::Map{A,D}) where {A,D}
    # Get the link histogram first - this will make later analysis steps much
    # easier as we won't have to traverse through the architecture a bunch
    # of times.
    histogram = global_link_histogram(m)

    # Print the total number of communication links in the taskgraph
    num_links = sum(values(histogram))
    print_with_color(:yellow, "Number of communication channels: ")
    print_with_color(:white, num_links, "\n")

    # Report the total number of links used - this will be the sum of the
    # number of links with a given length multiplied by the length.
    total = sum(k*v for (k,v) in histogram)
    print_with_color(:yellow, "Total global routing links used: ")
    print_with_color(:white, total, "\n")

    # Report the average link length
    average_length = total / num_links
    print_with_color(:yellow, "Average Link Length: ")
    print_with_color(:white, average_length, "\n")

    # Print the maximum link distance
    print_with_color(:yellow, "Maximum Link Distance: ")
    print_with_color(:white, maximum(keys(histogram)), "\n")

    # Display the link histogram
    print_with_color(:yellow, "Link Histogram: \n")
    display(histogram)

    return histogram
end

function global_link_histogram(m::Map{A,D}) where {A,D}
    histogram = SortedDict{Int64,Int64}()
    for edge in m.mapping.edges
        link_count = 0
        for node in edge.path
            if isglobal(node)
                link_count += 1
            end
        end
        add_to_dict(histogram, link_count)
    end
    return histogram
end

"""
    isglobal(path::AbstractPath)

Return `true` if the provided path is a global routing link.
"""
function isglobal(path::AbstractPath)
    if typeof(path) <: LinkPath && isempty(path.path.address)
        return true
    end
    return false
end
