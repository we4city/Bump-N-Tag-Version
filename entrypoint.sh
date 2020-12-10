#!/bin/sh -l
set -e

# Validations
if [ -z "$GITHUB_TOKEN" ]; then
	echo "Set the GITHUB_TOKEN env variable."
	exit 1
fi



file_name=$1
tag_version=$2
echo "\nInput file name: $file_name : $tag_version"

echo "Git Head Ref: ${GITHUB_HEAD_REF}"
echo "Git Base Ref: ${GITHUB_BASE_REF}"
echo "Git Event Name: ${GITHUB_EVENT_NAME}"

echo "\nStarting Git Operations"
set -o xtrace

git fetch origin $BRANCH
git checkout $BRANCH
git config --global user.email "Bump-N-Tag@github-action.com"
git config --global user.name "Bump-N-Tag App"

github_ref=""

if test "${GITHUB_EVENT_NAME}" = "push"
then
    github_ref=${GITHUB_REF}
else
    github_ref=${GITHUB_HEAD_REF}
    git checkout $github_ref
fi


echo "Git Checkout"

if test -f $file_name; then
    content=$(cat $file_name)
else
    content=$(echo "-- File doesn't exist --")
fi

echo "File Content: $content"
extract_string=$(echo $content | awk '/^([[:space:]])*(v|ver|version|V|VER|VERSION)?([[:blank:]])*([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{1,3})(\.([0-9]{1,5}))?[[:space:]]*$/{print $0}')
echo "Extracted string: $extract_string"

if [[ "$extract_string" == "" ]]; then 
    echo "\nInvalid version string"
    exit 0
else
    echo "\nValid version string found"
fi


increment_version() {
    for v in $1 ; do
        num=${v//./}
        let num++

        re=${v//./)(}
        re=${re//[0-9]/.}')'
        re=${re#*)}

        count=${v//[0-9]/}
        count=$(wc -c<<<$count)
        out=''
        for ((i=count-1;i>0;i--)) ; do
            out='.\'$i$out
        done

        sed -r s/$re$/$out/ <<<$num
    done
}


newver=$(increment_version $extract_string)


echo 'Updated from' $extract_string ' to ' $newver

git add -A 
git commit -m "New Version ${newver}"  -m "[skip ci]"

([ -n "$tag_version" ] && [ "$tag_version" = "true" ]) && (git tag -a "${newver}" -m "[skip ci]") || echo "No tag created"

git show-ref
echo "Git Push"

git push --follow-tags "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:$github_ref


echo "\nEnd of Action\n\n"
exit 0
