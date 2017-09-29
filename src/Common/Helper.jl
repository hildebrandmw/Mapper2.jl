"""
    oneofin(a, b)

Return `true` if at least one element of collection `a` is in collection `b`.
"""
function oneofin(a, b)
   for i in a
      in(i, b) && return true
   end
   return false
end
