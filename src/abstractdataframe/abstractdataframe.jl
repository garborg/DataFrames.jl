#' @@name AbstractDataFrame
#'
#' @@description
#'
#' An AbstractDataFrame is a Julia abstract type for which all concrete
#' types expose an database-like interface.
abstract AbstractDataFrame

##############################################################################
##
## Interface (not final)
##
##############################################################################

# index(df) => AbstractIndex
# nrow(df) => Int
# ncol(df) => Int
# getindex(...)
# setindex!(...) exclusive of methods that add new columns

##############################################################################
##
## Basic properties of a DataFrame
##
##############################################################################

immutable Cols{T <: AbstractDataFrame}
    df::T
end
Base.start(::Cols) = 1
Base.done(itr::Cols, st) = st > length(itr.df)
Base.next(itr::Cols, st) = (itr.df[st], st + 1)

# N.B. where stored as a vector, 'columns(x) = x.vector' is a bit cheaper
columns{T <: AbstractDataFrame}(df::T) = Cols{T}(df)

Base.names(df::AbstractDataFrame) = names(index(df))
_names(df::AbstractDataFrame) = _names(index(df))

function names!(df::AbstractDataFrame, vals)
    names!(index(df), vals)
    return df
end

function rename!(df::AbstractDataFrame, args...)
    rename!(index(df), args...)
    return df
end
rename!(f::Function, df::AbstractDataFrame) = rename!(df, f)

rename(df::AbstractDataFrame, args...) = rename!(copy(df), args...)
rename(f::Function, df::AbstractDataFrame) = rename(df, f)

function eltypes(df::AbstractDataFrame)
    ncols = size(df, 2)
    res = Array(Type, ncols)
    for j in 1:ncols
        res[j] = eltype(df[j])
    end
    return res
end

Base.size(df::AbstractDataFrame) = (nrow(df), ncol(df))
function Base.size(df::AbstractDataFrame, i::Integer)
    if i == 1
        nrow(df)
    elseif i == 2
        ncol(df)
    else
        throw(ArgumentError("DataFrames have only two dimensions"))
    end
end

Base.length(df::AbstractDataFrame) = ncol(df)
Base.endof(df::AbstractDataFrame) = ncol(df)

Base.ndims(::AbstractDataFrame) = 2

##############################################################################
##
## Similar
##
##############################################################################

Base.similar(df::AbstractDataFrame, dims::Int) =
    DataFrame([similar(x, dims) for x in columns(df)], copy(index(df)))

nas{T}(dv::AbstractArray{T}, dims::Union(Int, (Int...))) =   # TODO move to datavector.jl?
    DataArray(Array(T, dims), trues(dims))

nas{T,R}(dv::PooledDataArray{T,R}, dims::Union(Int, (Int...))) =
    PooledDataArray(DataArrays.RefArray(zeros(R, dims)), dv.pool)

nas(df::AbstractDataFrame, dims::Int) =
    DataFrame(Any[nas(x, dims) for x in columns(df)], copy(index(df)))

##############################################################################
##
## Equality
##
##############################################################################

function Base.isequal(df1::AbstractDataFrame, df2::AbstractDataFrame)
    size(df1, 2) == size(df2, 2) || return false
    isequal(index(df1), index(df2)) || return false
    for idx in 1:size(df1, 2)
        isequal(df1[idx], df2[idx]) || return false
    end
    return true
end

function Base.(:(==))(df1::AbstractDataFrame, df2::AbstractDataFrame)
    size(df1, 2) == size(df2, 2) || return false
    isequal(index(df1), index(df2)) || return false
    eq = true
    for idx in 1:size(df1, 2)
        coleq = df1[idx] == df2[idx]
        # coleq could be NA
        !isequal(coleq, false) || return false
        eq &= coleq
    end
    return eq
end

##############################################################################
##
## Associative methods
##
##############################################################################

Base.haskey(df::AbstractDataFrame, key::Any) = haskey(index(df), key)
Base.get(df::AbstractDataFrame, key::Any, default::Any) = haskey(df, key) ? df[key] : default
Base.isempty(df::AbstractDataFrame) = ncol(df) == 0

##############################################################################
##
## Description
##
##############################################################################

DataArrays.head(df::AbstractDataFrame, r::Int) = df[1:min(r,nrow(df)), :]
DataArrays.head(df::AbstractDataFrame) = head(df, 6)
DataArrays.tail(df::AbstractDataFrame, r::Int) = df[max(1,nrow(df)-r+1):nrow(df), :]
DataArrays.tail(df::AbstractDataFrame) = tail(df, 6)

# get the structure of a DF
function Base.dump(io::IO, df::AbstractDataFrame, n::Int, indent)
    println(io, typeof(df), "  $(nrow(df)) observations of $(ncol(df)) variables")
    if n > 0
        for (name, col) in eachcol(df)
            print(io, indent, "  ", name, ": ")
            dump(io, col, n - 1, string(indent, "  "))
        end
    end
end

function Base.dump(io::IO, dv::AbstractDataVector, n::Int, indent)
    println(io, typeof(dv), "(", length(dv), ") ", dv[1:min(4, end)])
end

# summarize the columns of a DF
# if the column's base type derives from Number,
# compute min, 1st quantile, median, mean, 3rd quantile, and max
# filtering NAs, which are reported separately
# if boolean, report trues, falses, and NAs
# if anything else, punt.
# Note that R creates a summary object, which has a print method. That's
# a reasonable alternative to this.
# TODO: clever layout in rows
describe(df::AbstractDataFrame) = describe(STDOUT, df)
function describe(io, df::AbstractDataFrame)
    for (name, col) in eachcol(df)
        println(io, name)
        describe(io, col)
        println(io, )
    end
end
describe(dv::AbstractDataVector) = describe(STDOUT, dv)
function describe{T<:Number}(io, dv::AbstractDataVector{T})
    if all(isna(dv))
        println(io, " * All NA * ")
        return
    end
    filtered = float(dropna(dv))
    qs = quantile(filtered, [0, .25, .5, .75, 1])
    statNames = ["Min", "1st Qu.", "Median", "Mean", "3rd Qu.", "Max"]
    statVals = [qs[1:3], mean(filtered), qs[4:5]]
    for i = 1:6
        println(io, string(rpad(statNames[i], 8, " "), " ", string(statVals[i])))
    end
    nas = sum(isna(dv))
    println(io, "NAs      $nas")
    println(io, "NA%      $(round(nas*100/length(dv), 2))%")
    return
end
function describe{T}(io, dv::AbstractDataVector{T})
    ispooled = isa(dv, PooledDataVector) ? "Pooled " : ""
    # if nothing else, just give the length and element type and NA count
    println(io, "Length  $(length(dv))")
    println(io, "Type    $(ispooled)$(string(eltype(dv)))")
    println(io, "NAs     $(sum(isna(dv)))")
    println(io, "NA%     $(round(sum(isna(dv))*100/length(dv), 2))%")
    println(io, "Unique  $(length(unique(dv)))")
    return
end

##############################################################################
##
## Miscellaneous
##
##############################################################################

function complete_cases(df::AbstractDataFrame)
    ## Returns a Vector{Bool} of indexes of complete cases (rows with no NA's).
    res = !isna(df[1])
    for i in 2:ncol(df)
        res &= !isna(df[i])
    end
    res
end

complete_cases!(df::AbstractDataFrame) = deleterows!(df, find(!complete_cases(df)))

function DataArrays.array(df::AbstractDataFrame)
    n, p = size(df)
    T = reduce(typejoin, eltypes(df))
    res = Array(T, n, p)
    idx = 1
    for col in columns(df)
        anyna(col) && error("DataFrame contains NAs")
        copy!(res, idx, data(col))
        idx += n
    end
    return res
end

function DataArrays.DataArray(df::AbstractDataFrame,
                              T::DataType = reduce(typejoin, eltypes(df)))
    n, p = size(df)
    res = DataArray(T, n, p)
    idx = 1
    for col in columns(df)
        copy!(res, idx, col)
        idx += n
    end
    return res
end

function nonunique(df::AbstractDataFrame)
    # Return a Vector{Bool} indicated whether the row is a duplicate
    # of a prior row.
    res = fill(false, nrow(df))
    di = Dict()
    for i in 1:nrow(df)
        if haskey(di, array(df[i, :])) # Used to convert to Any type
            res[i] = true
        else
            di[array(df[i, :])] = 1 # Used to convert to Any type
        end
    end
    res
end

unique!(df::AbstractDataFrame) = deleterows!(df, find(nonunique(df)))

# Unique rows of an AbstractDataFrame.
Base.unique(df::AbstractDataFrame) = df[!nonunique(df), :]

function nonuniquekey(df::AbstractDataFrame)
    # Here's another (probably a lot faster) way to do `nonunique`
    # by grouping on all columns. It will fail if columns cannot be
    # made into PooledDataVector's.
    gd = groupby(df, _names(df))
    idx = [1:length(gd.idx)][gd.idx][gd.starts]
    res = fill(true, nrow(df))
    res[idx] = false
    res
end

# Count the number of missing values in every column of an AbstractDataFrame.
function colmissing(df::AbstractDataFrame) # -> Vector{Int}
    nrows, ncols = size(df)
    missing = zeros(Int, ncols)
    for j in 1:ncols
        missing[j] = countna(df[j])
    end
    return missing
end

function without(df::AbstractDataFrame, icols::Vector{Int})
    newcols = _setdiff(1:ncol(df), icols)
    df[newcols]
end
without(df::AbstractDataFrame, i::Int) = without(df, [i])
without(df::AbstractDataFrame, c::Any) = without(df, index(df)[c])

##############################################################################
##
## Hcat / vcat
##
##############################################################################

# hcat's first argument must be an AbstractDataFrame
# Trailing arguments (currently) may also be DataVectors, Vectors, or scalars.

# hcat! is defined in dataframes/dataframes.jl
# Its first argument (currently) must be a DataFrame.

# catch-all to cover cases where indexing returns a DataFrame and copy doesn't
Base.hcat(df::AbstractDataFrame, x) = hcat!(df[:, :], x)

Base.hcat(df::AbstractDataFrame, x, y...) = hcat!(hcat(df, x), y...)

# vcat only accepts DataFrames. Finds union of columns, maintaining order
# of first df. Missing data becomes NAs.

Base.vcat(df::AbstractDataFrame) = df

Base.vcat(dfs::AbstractDataFrame...) = vcat(collect(dfs))

function Base.vcat{T<:AbstractDataFrame}(dfs::Vector{T})
    coltyps, colnams, similars = _colinfo(dfs)

    res = DataFrame()
    Nrow = sum(nrow, dfs)
    for j in 1:length(colnams)
        colnam = colnams[j]
        col = similar(similars[j], coltyps[j], Nrow)

        i = 1
        for df in dfs
            if haskey(df, colnam)
                copy!(col, i, df[colnam])
            end
            i += size(df, 1)
        end

        res[colnam] = col
    end
    res
end

_isnullable(::AbstractArray) = false
_isnullable(::AbstractDataArray) = true
const EMPTY_DATA = DataArray(Void, 0)

function _colinfo{T<:AbstractDataFrame}(dfs::Vector{T})
    df1 = dfs[1]
    colindex = copy(index(df1))
    coltyps = eltypes(df1)
    similars = collect(columns(df1))
    nonnull_ct = Int[_isnullable(c) for c in columns(df1)]

    for i in 2:length(dfs)
        df = dfs[i]
        for j in 1:size(df, 2)
            col = df[j]
            cn, ct = _names(df)[j], eltype(col)
            if haskey(colindex, cn)
                idx = colindex[cn]

                oldtyp = coltyps[idx]
                if !(ct <: oldtyp)
                    coltyps[idx] = promote_type(oldtyp, ct)
                end
                nonnull_ct[idx] += !_isnullable(col)
            else # new column
                push!(colindex, cn)
                push!(coltyps, ct)
                push!(similars, col)
                push!(nonnull_ct, !_isnullable(col))
            end
        end
    end

    for j in 1:length(colindex)
        if nonnull_ct[j] < length(dfs) && !_isnullable(similars[j])
            similars[j] = EMPTY_DATA
        end
    end
    colnams = _names(colindex)

    coltyps, colnams, similars
end

##############################################################################
##
## Hashing
##
## Make sure this agrees with is_equals()
##
##############################################################################

function Base.hash(df::AbstractDataFrame)
    h = hash(size(df)) + 1
    for i in 1:size(df, 2)
        h = hash(df[i], h)
    end
    return @compat UInt(h)
end
