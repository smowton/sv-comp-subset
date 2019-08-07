# Driver scripts for a subset of SV-COMP, for benchmarking CBMC and JBMC

This is a collection of modified run descriptions from SV-COMP 19
(the .yml files are from https://github.com/sosy-lab/sv-benchmarks and the
.xml files are from https://github.com/sosy-lab/sv-comp). They are
subsetted to target a benchmark time of around 2 hours, and the timeouts
are reduced to 30 seconds per run.

The C benchmarks run around 1 in 25 of the SV-COMP examples. The Java
benchmarks run all the SV-COMP Java examples as they are much smaller
in number, and only differ in that the timeout is shorter than in the
real SV-COMP.

We provide a script run-benchmark.sh which takes care of all preliminaries
and dependency setup, aiming to be runnable with little or no preparation on a clean machine.

## Setup

(For a typical Ubuntu machine):

    sudo apt-get install python3 python3-pip g++ gcc flex bison make git libwww-perl patch openjdk-8-jdk maven
    sudo chmod o+wt '/sys/fs/cgroup/cpuset/'
    sudo chmod o+wt '/sys/fs/cgroup/cpu,cpuacct/user.slice'
    sudo chmod o+wt '/sys/fs/cgroup/freezer/'
    sudo chmod o+wt '/sys/fs/cgroup/memory/user.slice'
    sudo swapoff -a

## Usage

To benchmark a branch "mybranch" available in repository "https://myserver/myrepo"
against whatever point in cbmc's develop branch it is based on:

    git clone https://github.com/diffblue/sv-comp-subset.git
    cd sv-comp-subset
    ./run-benchmark.sh c https://myserver/myrepo mybranch ~/mybranch-results

If you want a JBMC benchmark, exchange 'c' for 'java'. If running in a distcc or
similar distributed compilation environment, add --distcc to the end, and you should
probably set CXX and CC to use distcc, icecc or similar. In my case I use icecc via
ccache, so I set CC="ccache gcc" CXX="ccache g++" ./run-benchmark.sh ... --distcc

When the script completes view ~/mybranch-results/results/results/*.html to see
the result summary. The header at the top shows the two builds of CBMC or JBMC
that were tested, along with their Git commit IDs and a tag showing which is the
branch build (the one being tested) and which is the parent commit on develop
(the base for comparison).

Pay particular attention to the total cputime at the bottom
of the table, and the "local summary" row, which excludes those runs which timed
out.
