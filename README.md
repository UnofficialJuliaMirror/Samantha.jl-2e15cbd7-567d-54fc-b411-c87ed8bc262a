# Samantha.jl

[![pipeline status](https://gitlab.com/Samantha.ai/Samantha.jl/badges/master/pipeline.svg)](https://gitlab.com/Samantha.ai/Samantha.jl/commits/master)

Spiking neural network engine written in Julia, which is primarily aimed at creating and running human-like AI agents in real-time.

## Goals
* High-performance spiking neural network core  
* Stable real-time operation and interactivity  
* Flexible choice of various algorithms and parameters  
* Persistence of data at the filesystem level via file mmap  
* Acceleration of algorithms via GPUs or other offloading hardware  
* Efficient usage of high-performance network fabrics  

## Installation
Install a supported version of Julia (currently 0.6 or greater) on a supported OS.  
```
Pkg.clone("https://gitlab.com/Samantha.ai/Samantha.jl")
```

## Dependencies
### Operating System and Kernel
Samantha is designed to work primarily on GNU/Linux systems, but is also aimed at supporting any reasonable OS/Kernel combination that Julia supports. Support for proprietary systems (OS X, Windows, etc.) is not a top priority, but will likely work regardless thanks to Julia's cross-platform nature.  

#### GNU/Linux
It is strongly recommended to use a recent Linux kernel, simply due to the rapid pace of performance and stability improvements (especially when using GPUs, NVMe SSDs, or other fancy new hardware).  

### Required Packages:
* MacroTools - For ensuring a consistent API and easing package development
* HDF5 - For on-disk storage and file mmap  

### Optional Packages:
None yet!  

## Repository Layout
LICENSE.md - License file  
README.md - This file!  
REQUIRE - Julia Dependency Requirements file  
TODO.md - General Todo list  
src/ - Source code  
src/stdlib/ - Standard Library  
test/ - Tests, tests, tests!  
test/tmp/ - Temporary test files  
test/tmp/data - Temporary data files  
test/tmp/log - Temporary log files  
test/tmp/run - Temporary run files  

## Contributing Guidelines
All reasonable issues and code submissions will be given a fair chance, but duplicates may be immediately rejected. Please use the issue/PR search features to see if someone else has already made a similar submission.  
Contributions will be accepted from anyone, regardless of their identity or ideology, and whether they are an individual or organization.  
All contributed code is automatically licensed under the same license as the rest of the repository's code (please see LICENSE.md for the current license).  
Bounties are not currently present, but I am willing to post them if there is interest. Please file an issue if you are offering a bounty for a specific type of contribution.  

## Code of Conduct
Be polite and understanding. If you are rude, insulting, or complain about something without offering a reasonable suggestion or PR, I have no qualms with removing your right to post or contribute.  
Please keep all issues and PRs on-topic. Banter should be taken offline. You can find myself and other contributors on Julia Slack or Discourse.  

## Forks and Ports
There are not (to my knowledge) any forks or ports of Samantha.jl, but I have nothing against one being created. Please let me know if you have created/know of an open source fork or port, and I will post a link to it here!

## License
Samantha is licensed as MIT. Please see LICENSE.md for the full license terms.
