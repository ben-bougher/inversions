function nodeAvg(n)
    # Returns an averaging operator for averaging nodes to grid centers
    
    Av = spdiagm(tuple(ones(n) * .5, ones(n) *.5),[0,-1])
    return Av'
end

    
function nodeAvg(n1,n2)
    # Returns an averaging operator for averaging nodes to grid centers

    Av = kron(nodeAvg(n2), nodeAvg(n1))
    return Av
end

function nodeAvg(n1,n2,n3)
    # Returns an averaging operator for averaging nodes to grid centers

    Av = kron(nodeAvg(n3), nodeAvg(n1,n2))
    return Av
end

function edgeAvg(n)
    return speye(n)
end

function edgeAvg(n1,n2)
    # Averages from edges to cell centers
    Av1 = kron(nodeAvg(n2), speye(n1))
    Av2 = kron( speye(n2), nodeAvg(n1))
    
    return [Av1 Av2] 
end 

function edgeAvg(n1,n2,n3)
    
    A1 = kron(nodeAvg(n3),kron(nodeAvg(n2),speye(n1))); 
    A2 = kron(nodeAvg(n3),kron(speye(n2),nodeAvg(n1))); 
    A3 = kron(kron(speye(n3), nodeAvg(n1)),nodeAvg(n2));
    
    return [A1 A2 A3]
end

function nodeDiff(n, dn)
    # Returns a difference operator to differentiate on the nodes of a grid

    D =  spdiagm(tuple(ones(n) * -1, ones(n) *1),[0,-1])/dn
    return D'
end


function nodeDiff(n1,n2, dn1, dn2)
    # Returns a difference operator to differentiate an n-element vector

    
    G1 = kron(speye(n2+1), nodeDiff(n1, dn1))
    G2 = kron(nodeDiff(n2, dn2), speye(n1+1))

    
    return [G1,G2]
end

function nodeDiff(n1,n2,n3,d1,d2,d3)

    G1 = kron(speye(n3+1), kron(speye(n2+1), nodeDiff(n1, d1)))
    G2 = kron(speye(n3+1), kron(nodeDiff(n2,d2), speye(n1+1)))
    G3 = kron(nodeDiff(n3,d3), kron(speye(n1+1), speye(n2+1)))

    return [G1,G2,G3]
end 


function helmholtz(rho, w, m, dv)
"""
Makes the helmoltz operators H and Q, HU=Qq
"""
    
    n_cells = size(m[:])
    
    # Make the operators
    V  = ones(n_cells...)*prod(dv)
    Av = nodeAvg(size(m)...)
    AvE = edgeAvg(size(m)...)
    G = nodeDiff(size(m)...,dv...)

    H = -G'*spdiagm(AvE'*(rho[:].*V))*G + spdiagm(Av'*((w^2)*V.*m[:]))

    Q = -spdiagm(Av'*V)
    return H, Q
end


function helmholtzDerivative(U,w,dv)


    Av = nodeAvg([size(U)...]-1 ...)
    
    n_cells = prod([size(U)...]-1)
    v = ones(n_cells)*prod(dv)

    G = w^2 * spdiagm(U[:])*Av'*spdiagm(v)

    return G
end 

    
