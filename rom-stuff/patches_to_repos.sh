cyan='tput setaf 6'
yellow='tput setaf 3'
reset='tput sgr0'

rootdir=$(pwd)

# Loop through each repo in the patches folder
for repo in `ls patches`
do
	repo_path=$(echo $repo | sed 's|_|/|g')
	echo -e "\n$($cyan)$repo_path$($reset)\n"

	# Loop through patches in each repo
	for patch in `ls patches/$repo/*`
	do
		pushd $repo_path > /dev/null
		git am $rootdir/$patch
		popd > /dev/null
	done
done
