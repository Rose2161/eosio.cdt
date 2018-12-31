OS_VER=$( grep VERSION_ID /etc/os-release | cut -d'=' -f2 | sed 's/[^0-9\.]//gI' | cut -d'.' -f1 )

MEM_MEG=$( free -m | sed -n 2p | tr -s ' ' | cut -d\  -f2 )
CPU_SPEED=$( lscpu | grep "MHz" | tr -s ' ' | cut -d\  -f3 | cut -d'.' -f1 )
CPU_CORE=$( nproc )
MEM_GIG=$(( ((MEM_MEG / 1000) / 2) ))
JOBS=$(( MEM_GIG > CPU_CORE ? CPU_CORE : MEM_GIG ))

DISK_TOTAL=$( df -h . | grep /dev | tr -s ' ' | cut -d\  -f2 | sed 's/[^0-9]//' )
DISK_AVAIL=$( df -h . | grep /dev | tr -s ' ' | cut -d\  -f4 | sed 's/[^0-9]//' )

DEP_ARRAY=( 
	sudo procps which gcc72 gcc72-c++ autoconf automake libtool make \
    bzip2 bzip2-devel openssl-devel gmp gmp-devel libstdc++72 python27 python27-devel python34-devel \
    libedit-devel ncurses-devel swig wget file
)
COUNT=1
DISPLAY=""
DEP=""

# Enter working directory
mkdir -p $SRC_LOCATION
cd $SRC_LOCATION

printf "\\nOS name: ${OS_NAME}\\n"
printf "OS Version: ${OS_VER}\\n"
printf "CPU speed: ${CPU_SPEED}Mhz\\n"
printf "CPU cores: %s\\n" "${CPU_CORE}"
printf "Physical Memory: ${MEM_MEG} Mgb\\n"
printf "Disk install: ${DISK_INSTALL}\\n"
printf "Disk space total: ${DISK_TOTAL%.*}G\\n"
printf "Disk space available: ${DISK_AVAIL%.*}G\\n"

if [ "${MEM_MEG}" -lt 7000 ]; then
	printf "\\tYour system must have 7 or more Gigabytes of physical memory installed.\\n"
	printf "\\texiting now.\\n"
	exit 1
fi

if [ "${OS_VER}" -lt 2017 ]; then
	printf "\\tYou must be running Amazon Linux 2017.09 or higher to install EOSIO.\\n"
	printf "\\texiting now.\\n"
	exit 1
fi

if [ "${DISK_AVAIL}" -lt "${DISK_MIN}" ]; then
	printf "\\tYou must have at least %sGB of available storage to install EOSIO.CDT.\\n" "${DISK_MIN}"
	printf "\\texiting now.\\n"
	exit 1
fi

printf "\\n\\tChecking Yum installation.\\n"
if ! YUM=$( command -v yum 2>/dev/null )
then
	printf "\\n\\tYum must be installed to compile EOS.IO.\\n"
	printf "\\n\\tExiting now.\\n"
	exit 1
fi
printf "\\tYum installation found at %s.\\n" "${YUM}"

printf "\\nDo you wish to update YUM repositories?\\n\\n"
select yn in "Yes" "No"; do
	case $yn in
		[Yy]* ) 
			printf "\\n\\nUpdating...\\n\\n"
			if ! sudo "${YUM}" -y update; then
				printf "\\nYUM update failed.\\n"
				printf "\\nExiting now.\\n\\n"
				exit 1;
			else
				printf "\\nYUM update complete.\\n"
			fi
		break;;
		[Nn]* ) echo "Proceeding without update!";;
		* ) echo "Please type 1 for yes or 2 for no.";;
	esac
done

printf "Checking RPM for installed dependencies...\\n"
for (( i=0; i<${#DEP_ARRAY[@]}; i++ )); do
	pkg=$( rpm -qi "${DEP_ARRAY[$i]}" 2>/dev/null | grep Name )
	if [[ -z $pkg ]]; then
		DEP=$DEP" ${DEP_ARRAY[$i]} "
		DISPLAY="${DISPLAY}${COUNT}. ${DEP_ARRAY[$i]}\\n"
		printf "!! Package %s ${bldred} NOT ${txtrst} found !!\\n" "${DEP_ARRAY[$i]}"
		(( COUNT++ ))
	else
		printf " - Package %s found.\\n" "${DEP_ARRAY[$i]}"
		continue
	fi
done
printf "\\n"
if [ "${COUNT}" -gt 1 ]; then
	printf "The following dependencies are required to install EOSIO.\\n"
	printf "${DISPLAY}\\n\\n"
	printf "Do you wish to install these dependencies?\\n"
	select yn in "Yes" "No"; do
		case $yn in
			[Yy]* )
				printf "Installing dependencies\\n\\n"
				if ! sudo "${YUM}" -y install ${DEP}; then
					printf "!! YUM dependency installation failed !!\\n"
					printf "Exiting now.\\n"
					exit 1;
				else
					printf "YUM dependencies installed successfully.\\n"
				fi
			break;;
			[Nn]* ) echo "User aborting installation of required dependencies, Exiting now."; exit;;
			* ) echo "Please type 1 for yes or 2 for no.";;
		esac
	done
else
	printf " - No required YUM dependencies to install.\\n"
fi

printf "Checking CMAKE installation...\\n"
CMAKE=$(command -v cmake 2>/dev/null)
if [ -z $CMAKE ]; then
	printf "Installing CMAKE...\\n"
	curl -LO https://cmake.org/files/v$CMAKE_VERSION_MAJOR.$CMAKE_VERSION_MINOR/cmake-$CMAKE_VERSION.tar.gz \
	&& tar -xzvf cmake-$CMAKE_VERSION.tar.gz \
	&& cd cmake-$CMAKE_VERSION \
	&& ./bootstrap --prefix=$HOME \
	&& make -j"${CPU_CORE}" \
	&& make install \
	&& cd .. \
	&& rm -f cmake-$CMAKE_VERSION.tar.gz \
	|| exit 1
	printf " - CMAKE successfully installed @ ${CMAKE}.\\n"
else
	printf " - CMAKE found @ ${CMAKE}.\\n"
fi