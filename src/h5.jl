using HDF5
export LoadableBranch, Loadable
export object, store!, getdata, setdata!, getchild, getchildren, setchild!, gettype, settype!, getid, setid!, load, close!
export loadtree, locate, sweep
export CUR_H5_VERSION, MIN_H5_VERSION

### Consts ###

const CUR_H5_VERSION = v"1.0"
const MIN_H5_VERSION = v"1.0"

### Types ###

mutable struct Loadable <: AbstractLoadable
  filePath::String
  h5File::HDF5.HDF5File
  dataPath::String
  h5Data::Union{HDF5.HDF5File,HDF5.HDF5Group,HDF5.HDF5Dataset}
  branch::Union{AbstractBranch,Nothing}
end
Loadable(filePath, h5File, dataPath, h5Data) =
  Loadable(filePath, h5File, dataPath, h5Data, nothing)
function Loadable(filePath::String; new=false, ro=false)
  file = h5open(filePath, (new ? "w" : (ro ? "r" : "r+")))
  return Loadable(filePath, file, "", file)
end

mutable struct LoadableBranch{T} <: AbstractBranch
  id::String
  value::Union{T,Nothing}
  ldbl::AbstractLoadable
  parent::Union{AbstractBranch,Nothing}
  children::Vector{AbstractBranch}
  status::Symbol
end

### Methods ###

# Gets a branch's value
object(branch::LoadableBranch) = branch.value

# Top-level load from a file
function loadfile(ldbl::Loadable)
  version = getversion(ldbl)
  @assert version >= MIN_H5_VERSION "H5 version is too old: $version (Minimum: $MIN_H5_VERSION)"
  @assert version <= CUR_H5_VERSION "H5 version is too new: $version (Current: $CUR_H5_VERSION)"
  load(ldbl, "__TOP__", gettype(ldbl))
end
loadfile(path::String) = loadfile(Loadable(path))

# Top-level store to a file
# TODO: Handle reload
function storefile!(ldbl::Loadable, value::T; reload=false) where T
  setversion!(ldbl)
  settype!(ldbl, T)
  store!(ldbl, "__TOP__", value)
end
function storefile!(path::String, value)
  ldbl = Loadable(path; new=true)
  storefile!(ldbl, value)
  close!(ldbl)
end

# Get H5 version
getversion(ldbl) = VersionNumber(read(ldbl.h5Data["__VERSION__"]))

# Set H5 version
setversion!(ldbl) = write(ldbl.h5Data, "__VERSION__", string(CUR_H5_VERSION))

# Bottom-level load from a loadable
load(ldbl::Loadable, name, ::Type{T}) where T<:Array{Tuple{String,String,Symbol}} =
  Main.eval(parse(readdata(ldbl.h5Data[name])))
load(ldbl::Loadable, name, ::Type{T}) where T<:Array{String} =
  Main.eval(parse(readdata(ldbl.h5Data[name])))
load(ldbl::Loadable, name, ::Type{T}) where T<:AbstractContainer =
  CPUContainer(readdata(ldbl.h5Data[name]))
function load(pldbl::Loadable, name, ::Type{D}) where D<:Dict{K,V} where {K,V<:AbstractContainer}
  ldbl = getchild(pldbl, name)
  d = Dict{K,V}()
  for (cname,cldbl) in getchildren(ldbl)
    d[cname] = CPUContainer(load(ldbl, cname, gettype(cldbl)))
  end
  return d
end
load(ldbl::Loadable, name, ::Type{D}) where D<:Dict{K,V} where {K,V<:Any} =
  Main.eval(parse(readdata(ldbl.h5Data[name])))
load(ldbl::Loadable, name, ::Type{N}) where N<:Number =
  readdata(ldbl.h5Data[name])
load(ldbl::Loadable, name, ::Type{A}) where A<:AbstractArray{T} where T<:Number =
  readdata(ldbl.h5Data[name])
load(ldbl::Loadable, name, ::Type{S}) where S<:String =
  readdata(ldbl.h5Data[name])
load(ldbl::Loadable, name, ::Type{A}) where A<:Vector{Vector{Bool}} =
  Main.eval(parse(readdata(ldbl.h5Data[name])))
load(ldbl::Loadable, name, ::Type{A}) where A<:Array{Bool} =
  reinterpret(Bool, readdata(ldbl.h5Data[name]))
readdata(h5Data) = ismmappable(h5Data) ? readmmap(h5Data) : read(h5Data)

# Bottom-level store to a loadable
store!(ldbl::Loadable, name, data) = writedata!(ldbl.h5Data, name, string(data))
function store!(pldbl::Loadable, name, data::T) where T<:Dict{K,V} where {K,V<:AbstractContainer}
  ldbl = setchild!(pldbl, name)
  settype!(ldbl, T)
  for (key,value) in data
    store!(ldbl, string(key), value)
  end
end
store!(ldbl::Loadable, name, data::T) where T<:Dict{K,V} where {K,V<:Any} =
  writedata!(ldbl.h5Data, name, string(data))
store!(ldbl::Loadable, name, data::T) where T<:AbstractContainer =
  store!(ldbl, name, root(data))
store!(ldbl::Loadable, name, data::N) where N<:Number =
  writedata!(ldbl.h5Data, name, data)
store!(ldbl::Loadable, name, data::A) where A<:AbstractArray{T} where T<:Number =
  writedata!(ldbl.h5Data, name, data)
store!(ldbl::Loadable, name, data::A) where A<:Array{Bool} =
  writedata!(ldbl.h5Data, name, reinterpret(UInt8, data))
writedata!(h5Data, name, data) = write(h5Data, name, data)

# Gets a child loadable from a parent loadable
function getchild(parent::Loadable, name::String)
  @assert exists(parent.h5Data, name) "Child $name not found in parent $(parent.dataPath)"
  return Loadable(parent.filePath, parent.h5File, name, parent.h5Data[name])
end

# Gets all child loadables present in a parent loadable
function getchildren(parent::Loadable)
  children = Dict{String, Loadable}()
  for name in names(parent.h5Data)
    startswith(name, "__type") && continue
    children[name] = Loadable(parent.filePath, parent.h5File, name, parent.h5Data[name])
  end
  return children
end

# Sets a child group on a parent loadable and returns the child loadable
function setchild!(parent::Loadable, name::String)
  # Create HDF5 group with name
  group = g_create(parent.h5Data, name)
  groupName = HDF5.name(group)

  # Return new Loadable
  return Loadable(parent.filePath, parent.h5File, groupName, group)
end

# Gets the type field from the loadable
# TODO: Is assuming String reasonable?
gettype(ldbl::Loadable) = exists(ldbl.h5Data, "__type") ? Main.eval(parse(read(ldbl.h5Data["__type"]))) : String

# Sets the type field in the loadable
settype!(ldbl::Loadable, ::Type{T}) where T = write(ldbl.h5Data, "__type", string(T))

# Gets the id field from the loadable
getid(ldbl::Loadable) = read(ldbl.h5Data, "__id")

# Sets the id field in the loadable
setid!(ldbl::Loadable, id::String) = write(ldbl.h5Data, "__id", id)

# Returns an object from a loadable
function load(ldbl::Loadable)
  # Read loadable type name
  T = gettype(ldbl)
  
  if ldbl.branch == nothing
    ldbl.branch = LoadableBranch{T}(getid(ldbl), nothing, ldbl, nothing, AbstractBranch[], :added)
  end

  # Eval the type with the loadable to allow the object and its sub-objects to be loaded
  obj = T(ldbl)
  ldbl.branch.value = obj

  # Return loaded object
  return obj
end
function load(parent::Loadable, child::Loadable)
  # Create branch
  @assert child.branch == nothing "Child already has a branch"
  obj = load(child)
  child.branch = LoadableBranch(getid(child), obj, parent, parent.branch, AbstractBranch[], :added)
  push!(parent.branch.children, child.branch)
  return obj
end

# Loads and elaborates a tree
function loadtree(ldbl::Loadable, id::String)
  obj = load(ldbl)
  ldbl.branch.id = id
  return ldbl.branch
end
loadtree(filePath::String; ro=false) = loadtree(Loadable(filePath; ro=ro), filePath)

# Recursively locates an id using BFS
# TODO: Optimize by searching children first
function locate(branch::LoadableBranch, id::String; skip=true)
  if skip
    if branch.parent != nothing
      result = locate(branch.parent, id; skip=true)
      if result != nothing
        return result
      end
    else
      skip = false
    end
  end
  
  # Check self
  if branch.id == id
    return branch
  end

  # Check children
  for child in branch.children
    result = locate(child, id; skip=skip)
    if result != nothing
      return result
    end
  end

  # Failed to locate
  return nothing
end

# Sweeps the tree and returns non-normal branches
function sweep(branch::LoadableBranch)
  branches = []

  # Check self
  if branch.status != :normal
    push!(branches, branch)
  end

  # Check children
  for child in branch.children
    branches = vcat(branches, sweep(child))
  end

  return branches
end

# FIXME: Sweeps and cleans the tree
function sweep_clean!(branch::LoadableBranch)
  pairs = []

  # Check self
  if branch.status == :deleted
    # TODO: How to delete self?
  end

  # Check children
  for child in branch.children
    # TODO
  end

  return pairs
end

# Closes a loadable
close!(ldbl::Loadable) = close(ldbl.h5File)

function Base.show(io::IO, mt::MIME"text/plain", ldbl::Loadable)
  # FIXME: No path displayed
  println(io, "Loadable with data path: $(ldbl.dataPath): ")
end
function Base.show(io::IO, mt::MIME"text/plain", branch::LoadableBranch)
  println(io, "Branch [$(branch.id)] with $(length(branch.children)) children")
end

