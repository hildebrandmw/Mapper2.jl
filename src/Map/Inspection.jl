function report_routing_stats(m::Map{A,D}) where {A,D}
    # Get the link histogram first - this will make later analysis steps much
    # easier as we won't have to traverse through the architecture a bunch
    # of times.
    histogram = global_link_histogram(m)

    # Print the total number of communication links in the taskgraph
    num_links = sum(values(histogram))
    printstyled("Number of communication channels: ", color = :yellow)
    printstyled(num_links, "\n", color = :white)

    # Report the total number of links used - this will be the sum of the
    # number of links with a given length multiplied by the length.
    total = sum(k*v for (k,v) in histogram)
    printstyled("Total global routing links used: ", color = :yellow)
    printstyled(total, "\n", color = :white)

    # Report the average link length
    average_length = total / num_links
    printstyled("Average Link Length: ", color = :yellow)
    printstyled(average_length, "\n", color = :white)

    # Print the maximum link distance
    printstyled("Maximum Link Distance: ", color = :yellow)
    printstyled(maximum(keys(histogram)), "\n", color = :white)

    # Display the link histogram
    printstyled("Link Histogram: \n", color = :yellow)
    display(histogram)
    println()

    return histogram
end

function total_global_links(m::Map{A,D}) where {A,D}
    count = 0
    for edge in m.mapping.edges
        count += count_global_links(edge)
    end
    return count
end

function global_link_histogram(m::Map{A,D}) where {A,D}
    histogram = SortedDict{Int64,Int64}()
    for edge in m.mapping.edges
        link_count = count_global_links(edge)
        add_to_dict(histogram, link_count)
    end
    return histogram
end

function count_global_links(path)
    link_count = 0
    for v in vertices(path)
        if isgloballink(v)
            link_count += 1
        end
    end
    return link_count
end
