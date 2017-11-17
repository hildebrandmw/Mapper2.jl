using Plots
#Plots.gr()
Plots.pyplot()
################################################################################
# OH-NO PLOTTING
################################################################################

"""
    plot(sa::SAStruct)

Plot the SA Struct.
"""
function plot(sa::SAStruct)
    d = dimension(sa)
    if d == 2
        plot_2d(sa)
    elseif d == 3
        plot_3d(sa)
    else
        error("Cannot plot in $d dimensions")
    end
end

function plot_2d(sa::SAStruct)
   #pa = tg.architecture

   #addr_length = length(addresses(pa))
   num_nodes = length(sa.nodes)

   x1 = Int64[]
   y1 = Int64[]

   max_row      = 0
   max_column   = 0

   for index in eachindex(sa.component_table)
       if length(sa.component_table[index]) > 0
           # Convert to coordinates
           (x,y) = ind2sub(sa.component_table, index)
           push!(x1, x)
           push!(y1, y)
       end
   end

   max_row      = size(sa.component_table,1)
   max_column   = size(sa.component_table,2)

   num_links  = length(sa.edges)

   x = zeros(Float64, 2, num_links)
   y = zeros(Float64, 2, num_links)

   for (index, link) in enumerate(sa.edges)
       src = sa.nodes[link.sources[1]].address
       snk = sa.nodes[link.sinks[1]].address
       y[:,index] = [src.addr[2], snk.addr[2]]
       x[:,index] = [src.addr[1], snk.addr[1]]
   end

   distance = zeros(Float64, 1, num_links)
   lc_symbol = Array{Symbol}(1, num_links)

   ##  sort the link distances according to color ##

   for i = 1:num_links
      distance[i] = sqrt((x[1,i]-x[2,i])^2+(y[1,i]-y[2,i])^2)

      if distance[i] > 10
          lc_symbol[i] = :red
      elseif distance[i] > 1
          lc_symbol[i] = :blue
      else
          lc_symbol[i] = :black
      end

   end
   ## title and legend ##

   #title = join(("Mapping for: ", sa.application_name, " on ", pa.name))
   p = Plots.plot(legend = :none, size = (700,700))
   ## plot the architecture tiles ##
   Plots.plot!(x1, y1,  shape = :rect,
                        linewidth = 0.5,
                        color = :white,
                        markerstrokewidth = 1)
   ## plot task links ##
   Plots.plot!(x, y, line = :arrow,
               linewidth = 4.0,
               linecolor = lc_symbol,
               xlims = (0,max_row+1),
               ylims = (0,max_column+1),)
   ## export as png ##
   gui()
   #savefig("plot.png")
   return nothing
end

# Oh boy
function plot_3d(sa:: SAStruct)

  x1 = Int64[]
  y1 = Int64[]
  z1 = Int64[]

  max_row = 0
  max_column = 0
  max_level = 0

  for index in eachindex(sa.component_table)
       if length(sa.component_table[index]) > 0
           # Convert to coordinates
           (x,y,z) = ind2sub(sa.component_table, index)
           push!(x1, x)
           push!(y1, y)
           push!(z1, z)
       end
   end

   max_row      = size(sa.component_table,1)
   max_column   = size(sa.component_table,2)
   max_level    = size(sa.component_table,3)

   num_links  = length(sa.edges)

   x = zeros(Float64, 2, num_links)
   y = zeros(Float64, 2, num_links)
   z = zeros(Float64, 2, num_links)

   for (index, link) in enumerate(sa.edges)
       src = sa.nodes[link.sources[1]].address
       snk = sa.nodes[link.sinks[1]].address
       z[:,index] = [src.addr[3], snk.addr[3]]
       y[:,index] = [src.addr[2], snk.addr[2]]
       x[:,index] = [src.addr[1], snk.addr[1]]
   end

   distance = zeros(Float64, 1, num_links)
   lc_symbol = Array{Symbol}(1, num_links)

   ##  sort the link distances according to color ##

   for i = 1:num_links
      distance[i] = sqrt((x[1,i]-x[2,i])^2+(y[1,i]-y[2,i])^2+(z[1,i]-z[2,i])^2)

      if distance[i] > 10
          lc_symbol[i] = :black
      elseif distance[i] > 1
          lc_symbol[i] = :blue
      else
          lc_symbol[i] = :black
      end

   end
   ## title and legend ##

   #title = join(("Mapping for: ", sa.application_name, " on ", pa.name))
   p = Plots.plot(legend = :none, size = (700,700))
   ## plot the architecture tiles ##
   Plots.plot!(x1, y1, z1,
                shape = :circle,
                linewidth = 1,
                color = :black,
                markerstrokewidth = 1)

   ## plot task links ##
   Plots.plot!(x, y, z, line = :arrow,
               linewidth = 1,
               linecolor = lc_symbol,
               xlims = (0,max_row+1),
               ylims = (0,max_column+1),
               zlims = (0,max_level+1))

   ## export as png ##
   gui()
   #savefig("plot.png")
   return nothing
end
