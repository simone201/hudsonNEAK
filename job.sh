if [ -z "$HOME" ]
then
  echo HOME not in environment, guessing...
  export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

cd $WORKSPACE
mkdir -p ../neak
cd ../neak
export WORKSPACE=$PWD

if [ ! -d hudsonNEAK ]
then
  git clone git://github.com/simone201/hudsonNEAK.git
fi

cd hudsonNEAK
## Get rid of possible local changes
git reset --hard
git pull -s resolve

exec ./build.sh
