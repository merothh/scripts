branch=lineage-17.1

curl -s -L https://github.com/LineageOS/android/raw/$branch/default.xml | sed -rn 's#.*<project.*name="LineageOS/([^"]*).*#\1#p'
