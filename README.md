JuliaData
=========

Library for working with tabular data in Julia using `DataFrame`'s.

# Demos

See `demo/workflow_demo.jl` for a basic demo of the parts of a Julian data workflow.

See `demo/details_demo.jl` for a more in-depth demo of the DataFrame and related types and
library.

# DataFrame Overview and Design Decisions

Mainly Harlan here...

## Possible changes to Julia syntax

TShort: I don't know if we want this here, but I'm putting it out
there for review/discussion.

DataFrames fit well with Julia's syntax, but some features would
improve the user experience. 

### Keyword function arguments

[Issue 485](https://github.com/JuliaLang/julia/issues/485)

With many functions, it would be nice to have options. options.jl is
nice, but it is still clumsy from the user's point of view.

DataFrame creation would be cleaner:

```julia
d = DataFrame(a = [1:20],
              b = PooledDataVec([1:20]))
```              

In addition, a number of existing and planned functions are calling
out for optional arguments.

### ~ for easier expression syntax

It'd be nice to be able to do:

```julia
    by(df[~ a > 3], ["b", "c"], ~ x_sum = sum(x); y_mean = mean(y))
```    
A two-sided version would allow better formulas:

```julia
    lm(a ~ b)
```

~ is currently used as bitwise not, but it looks like it's not used
much, and this could be replaced by ! or by a function.


### Overloading .

df.col1 is nicer than df["col1"] for column access.

# Next Steps


