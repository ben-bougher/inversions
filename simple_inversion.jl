using PyCall
include("solvers.jl")
include("operators.jl")
include("operators_test.jl")
include("inversion_lib.jl")

plot_dir = "app_figures"

@pyimport matplotlib.pyplot as plt

n1 = 50;
n2 = 40;

smooth=30
#Pad and smooth models
#m = repmat(linspace(3,4,n1),1,n2);
m = zeros(n1+smooth,n2+smooth)
m[1:10,:] = 3.2
m[11:20,:]  = 3.5
m[21:30, :] = 3.8
m[31:end,:] = 4.0

m0 = conv2(ones(smooth,smooth), m)[smooth:end, smooth:end]/smooth^2;
m = m[1:n1,1:n2];
m0 = m0[1:n1,1:n2];



nq = n2
#plt.subplot("211");
#plt.imshow(m);
#plt.subplot("212");
#plt.imshow(m0);quad 
#plt.show();

dv = [1/n1,1/n2];

# PML params(top, bottom, left, right)
#sigma = 0;
#pad = (0,0,0,0);
sigma = 1e5;
pad = (30,30,30,30);
# define the rest
w = 30.0

# Apply the PML to the model
m_pad, Ia = pad_model(m, pad...);
m0_pad, dummy = pad_model(m0,pad...);
S, s12 = PML(m_pad, w, sigma, pad, dv);
S0, s0 = PML(m0_pad, w, sigma, pad, dv);


# Constant density
rho = ones(size(m_pad));

# make the q matrix
Q = zeros([size(m_pad)...]+1..., nq);
for i=1:size(Q)[3]
    q = zeros([size(m_pad)...]+1...)
    q[pad[1] + 1, pad[3]+i+2] +=1

    
    Q[:,:,i] = q;
end

# Receiver for every source
P = reshape(Q, prod(size(Q)[1:2]), size(Q)[3]);

#---------------------------------------------------------------#
# Solve the true forward problem
u = helmholtzNeumann(rho, w, m_pad, Q, dv,S, s12);
um = real(reshape(u, prod(size(u)[1:2]), size(u)[3]));
Dobs = real(P'*um)

plt.subplot("221")
plt.imshow(Dobs)
plt.subplot("222")
plt.imshow(real(u[:,:,1]))
plt.subplot("223")
plt.imshow(real(u[:,:,end]))
plt.subplot("224")
plt.imshow(m0) 
plt.show()
#--------------------------------------------------------------#

# Test the sensitivity
#A,dummy = helmholtz(rho,w,m_pad,dv, S, s12);
#adjointVectorTest(u,m, A, P, w, dv, s12, Ia)
#h,lin, quad = jacobianConvergence(rho,w,m_pad,m,Q,P,A,dv,S,s12,Ia)

#plt.plot(log(10,h),log(10,quad))
#plt.plot(log(10,h),log(10,lin))
#plt.show()

#--------------------------------------------------------------#


# Inversion through gradient descent---------------------------#

# Sove with m0
u = helmholtzNeumann(rho, w, m0_pad, Q, dv,S,s12);

D = real(P'*reshape(u, prod(size(u)[1:2]),  nq));

sig = 1.e9;
r = D - Dobs;
mis = 0.5*sig*(r[:]'*r[:]);

A,dummy = helmholtz(rho,w,m0_pad,dv,S,s12);
dmis = sig*jacobianTw(u, A, P, w, dv, r,s12,Ia);

# initialize parameters used in the loop
mc = m0_pad;
Ut=0;
mt = 0;
Dt=0;
rt=0;

all_misfit = Float32[]
it = 0
# loop through frequencies
for f = 1:60
    it = it +1
    
    w = f;
    sig = sig * 5/f
    S, s12 = PML(m_pad, w, sigma, pad, dv);
    u = helmholtzNeumann(rho, w, m_pad, Q, dv,S, s12);
    Dobs = real(P'*reshape(u, prod(size(u)[1:2]), size(u)[3]))
    

    S, s12 = PML(mc, w, sigma, pad, dv);
    Ut = helmholtzNeumann(rho, w, mc, Q, dv,S,s12);
    um = reshape(Ut, prod(size(u)[1:2]), nq);
    
    D = real(P'*um);
    
    r = D - Dobs;
    mis = 0.5*sig*(r[:]'*r[:]);
   
    A,dummy = helmholtz(rho,w,mc,dv,S,s12);

    dmis = sig*jacobianTw(u, A, P, w, dv, r, s12, Ia)
    dmis = dmis[:]

    # gradient iterations
    for i = 1:10
        muLS = 1;
        s = -dmis;

        # limit the gradient
        if maximum(abs(s))>0.1
            s = s/maximum(abs(s))*0.1 / f;
        end

        
        lscount = 1;
    

        while true

            mt = mc + reshape(real(Ia*muLS*s), size(mc))
            
            mt[real(mt).>4] = 4
            mt[real(mt).< 3] = 3
            
            Ut = helmholtzNeumann(rho, w, mt, Q, dv,S, s12);
        
            um = reshape(Ut, prod(size(u)[1:2]), nq);
            
            Dt = real(P'*um);

            rt = Dt - Dobs;
            
            mist = 0.5*sig*(rt[:]'*rt[:]);

            if mist[1] < mis[1]
                break
            end 
            
            muLS = muLS/2;
            lscount = lscount + 1;
            if lscount > 6
                print("DAMN")
                break
            end
       end

        mc = mt;

        D = Dt;
        U = Ut;
        r = rt ;
        ms = 0.5*sig*(r[:]'*r[:]);

        push!(all_misfit, ms[1]);

        A,dummy = helmholtz(rho,w,mc,dv,S, s12);
        
        dmis = sig*jacobianTw(U, A, P, w, dv, r, s12, Ia);

        plt.figure()
        plt.imshow(reshape(dmis, size(m)))
        file_name = string(plot_dir,"/",w,"_",i,"_", it,"_",
                           "gradient", ".png")
        plt.savefig(file_name)

        
        dmis = dmis[:]
        
        plt.figure()
        plt.imshow(reshape(Ia'*mc[:], size(m)))
        file_name = string(plot_dir,"/",w,"_",i,"_", it, "_",
                           "model", ".png")
        plt.savefig(file_name)

        plt.close("all")

        it = it +1
    end
end 


m_end = real(reshape(Ia'*mc[:], size(m)))

plt.figure()
plt.subplot("221")
plt.imshow(m)
plt.subplot("222")
plt.imshow(m0)
plt.subplot("223")
plt.imshow(m_end)
plt.subplot("224")
plt.imshow(m - m_end)

plt.show()

print(norm(m-m_end))
