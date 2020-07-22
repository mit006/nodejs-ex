#This script sets the env and branch values in Dockerfile and  package.json
env="$1"
echo '=============================='
echo "$1"
echo '=============================='

if [[ $env == prod ]]
  then
    echo '========================================================='
    echo "Caution !!! This is PRODUCTION system for MCCS."
    echo '========================================================='
    sed -i "s/\(git.*\)#dev/\1/" package.json
  else
    sed -i "s/\(git.*#\)dev/\1$env/" package.json
fi
sed -i "s/\(ENV[ ]*NODE_ENV\) dev/\1 $env/" Dockerfile

echo '========================================================='
echo "Set the environment values in package.json and Dockerfile"
echo '========================================================='
