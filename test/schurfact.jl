# Test if we can transform part of a Hessenberg matrix to Schur form.
# Here we look at some edge cases.

using Test, LinearAlgebra
using IRAM: eigvalues, local_schurfact!, is_offdiagonal_small, backward_subst!

include("utils.jl")

@testset "Schur factorization" begin
    let
        # 2-by-2 matrix with distinct eigenvalues while H[2,1] != 0
        H = [1.0 2.0; 3.0 4.0]
        H′ = copy(H)
        Q = Matrix{Float64}(I, 2, 2)
        
        @test local_schurfact!(H′, 1, 2, Q, eps(), 2)
        @test norm(H * Q - Q * H′) < 10eps()
        @test sort!(eigvalues(H′), by=realimag) ≈ sort!(eigvals(H′), by=realimag)
        @test sort!(eigvalues(H′), by=realimag) ≈ sort!(eigvals(H), by=realimag)
        @test iszero(H′[2,1])
    end

    let
        # 2-by-2 matrix with distinct eigenvalues while H[2,1] = 0
        H = [1.0 2.0; 0.0 4.0]
        H′ = copy(H)
        Q = Matrix{Float64}(I, 2, 2)
        
        @test local_schurfact!(H′, 1, 2, Q, eps(), 2)
        @test norm(H * Q - Q * H′) < 10eps()
        @test sort!(eigvalues(H′), by=realimag) ≈ sort!(eigvals(H′), by=realimag)
        @test sort!(eigvalues(H′), by=realimag) ≈ sort!(eigvals(H), by=realimag)
        @test iszero(H′[2,1])
    end

    let
        # 2-by-2 matrix with conjugate eigenvalues
        H = [1.0 4.0; -5.0 3.0]
        H′ = copy(H)
        Q = Matrix{Float64}(I, 2, 2)
        
        @test local_schurfact!(H′, 1, 2, Q, eps(), 2)
        @test norm(H * Q - Q * H′) < 10eps()
        @test sort!(eigvalues(H′), by=realimag) ≈ sort!(eigvals(H′), by=realimag)
        @test sort!(eigvalues(H′), by=realimag) ≈ sort!(eigvals(H), by=realimag)
    end
    
    # Larger real matrix.

    let
        n = 10
        # Transforming a 1+i by n-i block of the matrix H into upper triangular form
        for i = 0 : 4
            Q = Matrix{Float64}(I, n, n)
            H = triu(randn(Float64, n, n))
            H[1+i:n-i,1+i:n-i] = normal_hessenberg_matrix(Float64, i+1:n-i)
            H′ = copy(H)

            # Test that the procedure has converged
            @test local_schurfact!(H′, 1+i, n-i, Q)

            for j = 1+i:n-i-1
                t = H′[j,j] + H′[j+1,j+1]
                d = H′[j,j] * H′[j+1,j+1] - H′[j+1,j] * H′[j,j+1]

                # Test if subdiagonal is small. If not, check if conjugate eigenvalues.
                @test is_offdiagonal_small(H′, j) || t^2 < 4d
            end

            # Test that the elements below the subdiagonal are 0
            @test is_hessenberg(H′)

            # Test that the partial Schur decomposition relation holds
            @test norm(H * Q - Q * H′) < 1000eps()
            
            # Test that the eigenvalues of H are the same before and after transformation
            @test sort!(eigvals(H), by=realimag) ≈ sort!(eigvals(H′), by=realimag)
        end

    end


    # COMPLEX ARITHMETIC

    let
        n = 10
        # Transforming a 1+i by 10-i block of the matrix H into upper triangular form
        for i = 0 : 4
            Q = Matrix{ComplexF64}(I, n, n)
            H = triu(randn(ComplexF64, n, n))
            H[i+1:n-i,i+1:n-i] = normal_hessenberg_matrix(ComplexF64, (i+1:n-i) .* (1 + im))
            H′ = copy(H)

            # Test that the procedure has converged
            @test local_schurfact!(H′, 1+i, n-i, Q)

            # Test if subdiagonal is small. 
            for j = 1+i:n-i-1
                @test iszero(H′[j+1,j])
            end

            # Test that the elements below the subdiagonal are 0
            @test is_hessenberg(H′)

            # Test that the partial Schur decomposition relation holds
            @test norm(H * Q - Q * H′) < 1000eps()
            
            # Test that the eigenvalues of H are the same before and after transformation
            @test sort!(eigvals(H), by=realimag) ≈ sort!(eigvals(H′), by=realimag)
        end

    end
end

@testset "Backward subsitution" begin

    # Test whether the eigenvector comes out properly
    for T in (Float64,ComplexF64)
        R = triu(rand(T, 10,10))
        for i = 2:10
            R_small = copy(R[1:i-1,1:i-1])
            λs, vs = eigen(R)
            y = -R[1:i-1,i]

            x = (R_small-I*R[i,i]) \ y

            backward_subst!(R_small, R[i,i], y)
            eigvec = [y; 1.0; zeros(Float64, 10-i)] / norm([y; 1.0; zeros(Float64, 10-i)])
            
            @test x ≈ y
            @test abs.(vs[:,i]) ≈ abs.(eigvec)
        end
    end

    #Real arithmetic with conjugate eigvals
    for i = 6:10
        R = triu(rand(10,10))
        R[i-4,i-5] = rand()
        R[i-2,i-3] = rand()
        R_small = copy(R[1:i-1,1:i-1])
        λs, vs = eigen(R)
        y = -R[1:i-1,i]
        x = (R_small-I*R[i,i]) \ y

        backward_subst!(R_small, R[i,i], y)
        eigvec = [y; 1.0; zeros(Float64, 10-i)] / norm([y; 1.0; zeros(Float64, 10-i)])
            
        @test x ≈ y
        @test vs[:,i] ≈ eigvec
    end

    #Repeated eigvals at different positions.
    for T in (Float64,ComplexF64)
        for i = 6:10
            R = triu(rand(T, 10,10))
            lambda = rand(T)
            R[i-2,i-2] = lambda
            R[i-3,i-3] = lambda
            R[i,i] = lambda
            λs, vs = eigen(R)
            R_small = R[1:i-1,1:i-1]
            y = [-R[1:i-1,i]; 1.0]

            backward_subst!(R_small, R[i,i], y)
            eigvec = [y; zeros(Float64, 10-i)] / norm([y; zeros(Float64, 10-i)])
                
            @test abs.(vs[:,i]) ≈ abs.(eigvec)
            # @show eigvec
            # @show vs[:,i]
        end
    end

    # Repeated eigvals. Test that all eigenvectors are correct.
    for T in (Float64,ComplexF64)
        R = triu(rand(T, 10,10))
        lambda = rand(T)
        R[9,9] = lambda
        R[8,8] = lambda
        R[7,7] = lambda
        λs, vs = eigen(R)

        for i = 10:-1:1
            R_small = R[1:i-1,1:i-1]
            y = [-R[1:i-1,i]; 1.0]

            backward_subst!(R_small, R[i,i], y)
            eigvec = [y; zeros(Float64, 10-i)] / norm([y; zeros(Float64, 10-i)])
                
            @test abs.(vs[:,i]) ≈ abs.(eigvec)
        end
    end

    #Geometric multiplicity > 1
    for T in (Float64,ComplexF64)
        R = triu(rand(T, 10,10))
        lambda = rand(T)
        R[9,9] = lambda
        R[8,8] = lambda
        R[8,9] = zero(T)
        R[7,7] = lambda
        R[7,9] = zero(T)
        R[7,8] = zero(T)
        λs, vs = eigen(R)

        for i = 10:-1:1
            R_small = R[1:i-1,1:i-1]
            y = [-R[1:i-1,i]; 1.0]

            backward_subst!(R_small, R[i,i], y)
            eigvec = [y; zeros(Float64, 10-i)] / norm([y; zeros(Float64, 10-i)])
            # @show eigvec
            # @show vs[:,i]
            @test abs.(vs[:,i]) ≈ abs.(eigvec)
        end
    end

    #Eigenvectors for conjugate eigenvalues
    let
        R = triu(rand(Float64, 10,10))
        a = rand(Float64)
        R[10,10] = a 
        R[9,9] = a
        R[9,10] = -3a
        R[10,9] = a
        R[5,4] = a
        λs, vs = eigen(R)

        y = Vector{ComplexF64}(undef, 10)
        backward_subst!(R, y)
        y ./= norm(y)
        @test abs.(vs[:,9]) ≈ abs.(y)
    end

    let
        R = triu(rand(Float64, 10,10))
        a = rand(Float64)
        R[6,6] = a 
        R[5,5] = a
        R[5,6] = -3a
        R[6,5] = a
        λs, vs = eigen(R)

        y = Vector{ComplexF64}(undef, 10)
        backward_subst!(R[1:6,1:6], y)
        y ./= norm(y)
        @test abs.(vs[:,5]) ≈ abs.(y)
    end
end