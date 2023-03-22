#!/bin/bash

usage() { echo -e "Usage: ${0} [-p <pool name>] [-o <osd id number>]\n At least an OSD number (-o) is required"  1>&2; exit 0; }

 verifiedPool="false" 

while getopts "p:o:h" f; do
    case "${f}" in
        p)
            pool=${OPTARG}            
            ;;
        o)
            osd=${OPTARG}
            ;;
	h)
	    usage
	    ;;
	*)
            usage
            ;;
    esac
done

if [[ -z "$pool" && -z "$osd" ]]; then
	usage  
fi
if [[ -z "$osd" ]]; then
    usage
    "Please enter an OSD ID Number (option -o)"
fi

if [ -z "$pool" ]; then
    pool="all"
fi

for pools in $(ceph osd pool ls)
do
    if [ $pools == $pool ]; then 
        verifiedPool = "true"
    fi
done

if [ $verifiedPool == "false" ]; then
    echo "Pool could not be found in ceph cluster. Please check your pool name and try again."
    exit 0;
fi 

if [ $pool == "all" ]; then 
        echo "Checking all pools"
    else
        echo "Checking pool $pool"
fi
echo "OSD $osd on Host $(ceph osd find 4 | grep host | cut -d \" -f 4 | sort -u)"
echo "Please wait. This may take a while depending on the size of the Ceph Cluster..."

for i in $(ceph pg ls-by-osd $osd | cut -d " " -f 1 | grep \. | tail -n +2 | head -n -1)
do
    for object in $(rados --pgid $i ls | cut -d "." -f 2)
    do
        echo -e $object >> /tmp/tempobjectsinpgs.txt
    done
done
sort /tmp/tempobjectsinpgs.txt > /tmp/tempobjectsinpgs_sorted.txt
awk '!seen[$0]++' /tmp/tempobjectsinpgs_sorted.txt > /tmp/objectsinpgs.txt

if [ $pool == "all" ]; then
    while read objectid
    do
        for pool in $(ceph osd pool ls)
        do
            for image in $(rbd ls -p $pool)
            do
                if rbd info -p $pool $image | grep $objectid
                then
                    echo $image >> /tmp/imagesonosd.txt
                fi
            done
        done    
    done</tmp/objectsinpgs.txt
    sort /tmp/imagesonosd.txt > /tmp/imagesonosd_sorted.txt
    awk '!seen[$0]++' /tmp/imagesonosd_sorted.txt > affectedimages.txt
fi

if [ $pool != "all" ]; then
    while read objectid
    do
        for image in $(rbd ls -p $pool)
        do
            if rbd info -p CephVMs $image | grep $objectid
            then
                echo $image >> /tmp/imagesonosd.txt
            fi
        done
    done</tmp/objectsinpgs.txt
    sort /tmp/imagesonosd.txt > /tmp/imagesonosd_sorted.txt
    awk '!seen[$0]++' /tmp/imagesonosd_sorted.txt > affectedimages.txt
fi

    rm /tmp/objectsinpgs.txt /tmp/tempobjectsinpgs_sorted.txt /tmp/tempobjectsinpgs.txt /tmp/imagesonosd.txt /tmp/imagesonosd_sorted.txt



echo -e "\n\nDONE! Please view the file located in the current directory labeled affectedimages.txt"\n
echo -e "Please rename this file before running again."
