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
	curl -H "Authorization: token $GITHUB_PERSONAL_TOKEN" --data "{\"name\": \"${repos[index]}\"}" https://api.github.com/orgs/$organization/repos
done
