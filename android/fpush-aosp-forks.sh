manifest=manifest/snippets/bootleggers.xml
tag=android-10.0.0_r23
branch=queso
organization=git@github.com:org

cyan='tput setaf 6'
yellow='tput setaf 3'
red='tput setaf 1'
reset='tput sgr0'

repos=($(sed -rn 's/.*<project.*name="([^"]*).*/\1/p' $manifest))
paths=($(sed -rn 's/.*<project.*path="([^"]*).*/\1/p' $manifest))
branches=($(sed -rn -e 's/.*<project.*revision="([^"]*).*/\1/p' -e "s/.*project.*name=.*/${branch}/p" $manifest))

for ((index=0; index<${#repos[@]}; index++))
do
	echo "$($cyan)${repos[index]} $($yellow):$($cyan) ${paths[index]} $($yellow):$($cyan) ${branches[index]}$($reset)"
	pushd ${paths[$index]} &> /dev/null

	if [ $? -eq 0 ]
	then
		git branch -D mirror-tmp &> /dev/null
		git checkout -b mirror-tmp &> /dev/null
		git branch -D ${branches[index]} 2> /dev/null
		git checkout tags/$tag -b ${branches[index]}
		git push $organization/${repos[$index]} ${branches[index]} -f
		popd > /dev/null
	else
		echo "$($red)skipping $($yellow)${repos[index]}$($reset)"
	fi

	echo
done
