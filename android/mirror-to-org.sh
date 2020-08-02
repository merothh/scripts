manifest=manifest/snippets/bootleggers.xml
remote=bootleggers
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
	pushd ${paths[$index]} > /dev/null

	git branch -D mirror-tmp &> /dev/null
	git checkout -b mirror-tmp &> /dev/null
	git branch -D ${branches[index]} 2> /dev/null
	git checkout $remote/${branches[index]} -b ${branches[index]}
	git push $organization/${repos[$index]} ${branches[index]} -f

	popd > /dev/null
	echo
done
