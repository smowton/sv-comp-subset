#!/bin/bash

set -e

if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    echo "Usage: run-benchmark.sh c|java remote ref outdir [--distcc]"
    echo "Example: run-benchmark.sh c https://github.com/user/cbmc.git mybranch ~/results"
    exit 1
fi

benchmark=$1
if [ $benchmark != "c" ] && [ $benchmark != "java" ]; then
    echo "First argument must be 'c' or 'java'"
    exit 1
fi

remote=$2
branch_ref=$3
workdir=$4

if [ -d $workdir ]; then
    echo "$workdir already exists; won't overwrite"
    exit 1
fi 

distcc=0
if [ $# == 5 ]; then
    if [ $5 != "--distcc" ]; then
	echo "Unrecognised argument $5"
	exit 1
    fi
    distcc=1
fi

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
basedir=$workdir/base
branchdir=$workdir/branch
resultdir=$workdir/results

mkdir -p $basedir $branchdir $resultdir

processors=$(cat /proc/cpuinfo | grep ^processor /proc/cpuinfo | wc -l)

if ! touch /sys/fs/cgroup/cpuset/; then
    echo "Can't access /sys/fs/cgroup/cpuset/"
    echo "Suggest running:"
    echo "sudo chmod o+wt '/sys/fs/cgroup/cpuset/'"
    echo "sudo chmod o+wt '/sys/fs/cgroup/cpu,cpuacct/user.slice'"
    echo "sudo chmod o+wt '/sys/fs/cgroup/freezer/'"
    echo "sudo chmod o+wt '/sys/fs/cgroup/memory/user.slice'"
    exit 1
fi

if [ $(swapon --show | wc -c) -ne 0 ]; then
    echo "Looks like you have at least one swap partition mounted"
    echo "Suggest running:"
    echo "sudo swapoff -a"
    exit 1
fi
    
echo "Checking required repos..."
cd $scriptdir

for dependency in cprover-sv-comp sv-benchmarks benchexec cbmc; do
    if [ ! -d $dependency ]; then
	if [ $dependency == cprover-sv-comp ] || [ $dependency == cbmc ]; then
	    organisation=diffblue
	else
	    organisation=sosy-lab
	fi
	if [ $dependency == "cbmc" ]; then
	    depth=""
	else
	    depth="--depth=1"
	fi
	git clone $depth https://github.com/$organisation/$dependency.git
    fi
    if [ $dependency != cbmc ]; then
	(cd $dependency && git pull)
    fi
done

echo "Checking Python dependencies..."

pip3 install --user PyYAML tempita

echo "Building [cj]bmc-wrapper..."

make -C cprover-sv-comp cbmc-wrapper jbmc-wrapper

echo "Building cbmc..."

build_parallelism=$processors
if [ $distcc -eq 1 ]; then
    build_parallelism=50
fi

function build_cbmc {
    targetdir=$1
    tag=$2
    git submodule update --init --recursive
    make -C src minisat2-download
    make -C src -j$build_parallelism
    make -C jbmc/src -j$build_parallelism
    cp src/cbmc/cbmc $targetdir/cbmc-binary
    cp jbmc/src/jbmc/jbmc $targetdir/jbmc-binary    
    cp src/goto-cc/goto-cc $targetdir
    cp jbmc/lib/java-models-library/target/core-models.jar $targetdir
    cp $scriptdir/cprover-sv-comp/cbmc-wrapper $targetdir/cbmc
    cp $scriptdir/cprover-sv-comp/jbmc-wrapper $targetdir/jbmc
    sed -i "s/\\\$TOOL_BINARY --version/echo \"\$(\$TOOL_BINARY --version)\" \"($tag)\" /g" $targetdir/cbmc $targetdir/jbmc
}

(
    set -e
    cd cbmc
    git fetch $remote $branch_ref
    git checkout FETCH_HEAD
    build_cbmc $branchdir "BRANCH"
)

(
    set -e
    cd cbmc
    git fetch origin develop
    mergebase=$(git merge-base HEAD FETCH_HEAD)
    if [ $mergebase == "" ]; then
	echo "Given branch does not appear to be related to origin/develop (git merge-base branch vs. develop failed)"
	exit 1
    fi
    git checkout $(git merge-base HEAD FETCH_HEAD)
    build_cbmc $basedir "BASE"
)

echo "Benchmarking branch..."
(
    cd $branchdir
    $scriptdir/benchexec/bin/benchexec $scriptdir/$benchmark/*.xml --no-container
)

echo "Benchmarking develop..."
(
    cd $basedir
    $scriptdir/benchexec/bin/benchexec $scriptdir/$benchmark/*.xml --no-container
)

echo "Building report..."
(
    cd $resultdir
    $scriptdir/benchexec/bin/table-generator $basedir/results/*.xml.bz2 $branchdir/results/*.xml.bz2
)
