manifest=manifest/snippets/bootleggers.xml
organization=org

cyan='tput setaf 6'
yellow='tput setaf 3'
red='tput setaf 1'
reset='tput sgr0'

repos=($(sed -rn 's/.*<project.*name="([^"]*).*/\1/p' $manifest))

for ((index=0; index<${#repos[@]}; index++))
do
	echo "$($cyan)${repos[index]}$($reset)"
	curl -X DELETE -H "Authorization: token $GITHUB_PERSONAL_TOKEN" https://api.github.com/repos/$organization/${repos[index]}
done
