# Part of the alaterm project, https://github.com/Zenmyjf/alaterm/
# This file is: https://raw.githubusercontent.com/Zenmyjf/alaterm/master/08-alaterm.bash
#

echo "$(caller)" | grep -F 00-alaterm.bash >/dev/null 2>&1
if [ "$?" -ne 0 ] ; then
echo "Script 08-alaterm.bash is not stand-alone."
echo "It must be sourced in sequence from 00-alaterm.bash."
echo "Exit." ; exit 1
fi


##############################################################################
## INSTALLER PART 08. Create launch script, and finish.
##############################################################################


start_launchCommand() {
cat << EOC > "$launchCommand" # No hyphen. Unquoted marker. Single gt.
#!/bin/bash
# This is the launch command for alaterm, Arch Linux ARM in Termux.
# It is placed in Termux $PREFIX/bin by the installer script.
# A backup copy is placed in the top level of alaterm.
# If necessary, copy the backup copy into Termux $PREFIX/bin.
#
source "$alatermTop/status"
EOC
}

finish_launchCommand() { # Added to above.
cat << 'EOC' >> "$launchCommand" # No hyphen. Quoted marker. Double gt.
hash proot >/dev/null 2>&1
if [ "$?" -ne 0 ] ; then
	echo -e "\e[1;91mPROBLEM.\e[0m Termux does not have proot installed. Cannot launch alaterm."
	echo -e "Use Termux pkg to install proot, then try again.\n"
	exit 1
fi
# It is possible to install different vncservers in Termux, and in alaterm.
# If Termux vncserver is running when alaterm is launched, there will be conflict.
# This checks for active Termux vncserver:
hash vncserver >/dev/null 2>&1 # Refers to Termux vncserver.
if [ "$?" -eq 0 ] ; then
	vrps="$( vncserver -list | grep :[1234567890] )"
	if [ "$?" -eq 0 ] ; then # Termux vncserver is on.
		vrpn="$( echo \$vrps | sed 's/\s.*//g' )"
		echo -e "\e[1;33mWARNING.\e[0m Termux has its own vncserver active."
		echo "It will conflict with the vncserver launched by alaterm."
		echo "What do you wish to do?"
		echo "  k = Kill the Termux vncserver, then continue to launch alaterm."
		echo "  x = Do not launch alaterm. Termux vncserver remains on."
		while true ; do
			printf "Now \e[1;92menter\e[0m your choice [k|x] : " ; read readvar
			case "$readvar" in
				k*|K* ) vncserver -kill $vrpn >/dev/null 2>&1
				if [ "$?" -eq 0 ] ; then
					rm -f ~/.Xauthority
					touch ~/.Xauthority
					rm -f ~/.ICEauthority
					touch ~/.ICEauthority
					rm -r -f "$termuxPrefix/tmp/.X*"
					rm -f "$termuxPrefix/tmp/.X*"
					rm -f ~/.vnc/localhost*
					echo "Termux vncserver killed. Continuing to alaterm..."
				else
					echo -e "\e[1;91mPROBLEM.\e[0m Unable to autokill the Termux vncserver."
					echo "You may kill it manually, then try again."
					exit 1
				fi
				break ;;
				x|X ) echo "Script will exit without change."
				exit 1 ; break ;;
				* ) echo "No default. Choose k or x." ;;
			esac
		done
	fi
fi
# If you closed Termux or shut down your device while alaterm was running,
# then it left the alaterm directory in an inaccessible state.
# This is detected here, and fixed.
# But the launch script does not continue to launch. Instead, run it a second time.
# This gives you the opportunity to manually identify the problem from Termux,
# in case it was not fixed, without an infinite do-loop.
alatermstatnow="$(stat --format '%a' $alatermTop)"
if [ "$alatermstatnow" = "100" ] ; then
	chmod 755 "$alatermTop"
	echo -e "\e[1;33mINFO:\e[0m The last time you used alaterm, you did not logout correctly."
	echo "That caused a problem. It has now been fixed automatically."
	echo "This launch script will now exit. You may re-launch it."
	exit 1
fi
chmod 100 "$alatermTop" # Makes alaterm / invisible in PCManFM.
# The proot string tells how alaterm is configured within its proot confinement.
# Actually, it is not much confinement, since alaterm can access most outside files,
# and can even run a few Termux executables.
prsUser="proot --kill-on-exit --link2symlink -v -1 -0 -r $alatermTop " # zero
prsUser+="-b /proc -b /system -b /sys -b /dev -b /data -b /vendor "
[ ! -r /dev/ashmem ] && prsUser+="-b $alatermTop/tmp:/dev/ashmem " # Probably OK as-is.
[ ! -r /dev/shm ] && prsUser+="-b $alatermTop/tmp:/dev/shm " # Probably does not exist, but is expected.
[ ! -r /proc/stat ] && prsUser+="-b $alatermTop/var/binds/fakePS:/proc/stat "
[ ! -r /proc/version ] && prsUser+="-b $alatermTop/var/binds/fakePV:/proc/version "
[ -d /sdcard ] && prsUser+="-b /sdcard "
[ -d /storage ] && prsUser+="-b /storage "
prsUser+="-b /proc/self/fd/0:/dev/stdin -b /proc/self/fd/1:/dev/stdout -b /proc/self/fd/2:/dev/stderr "
prsUser+="-w /home "
prsUser+="/usr/bin/env - TERM=$TERM HOME=/home "
prsUser+="/bin/su -l user"
# The Termux LD_PRELOAD interferes with proot:
unset LD_PRELOAD
# Now to launch alaterm:
eval "exec $prsUser"
# The above command continues to run, until logout of alaterm. After logout:
chmod 755 "$alatermTop" # Restores ability to edit alaterm from Termux.
echo -e "\e[1;33mYou have left alaterm, and are now in Termux.\e[0m\n"
##
EOC
}

create_fakeLaunch() { # In alaterm /usr/bin.
fakelc="# File "
fakelc+="$alatermTop/usr/bin/$launchCommand."
cat << EOC > "$launchCommand" # No hyphen. Unquoted marker.
#!/bin/bash
$fakelc
# Fake launch script.
echo -e "\e[33mYou cannot launch alaterm from within alaterm.\e[0m"
##
EOC
}

ensure_noTVNC() { # In Termux home. Ensures no leftovers, if user runs vncserver outside alaterm.
	grep alaterm_installer .bash_logout >/dev/null 2>&1
	if [ "$?" -ne 0 ] ; then
		echo "vncserver -autokill >/dev/null 2>&1 || true # By_alaterm_installer." >> .bash_logout
	fi
}

restore_launchCommand() { # In Termux home. Deals with situation where $PREFIX is deleted and renewed.
	grep alaterm_installer .bashrc >/dev/null 2>&1
	if [ "$?" -ne 0 ] ; then
		echo "alatermTop=$alatermTop # By_alaterm_installer." >> .bashrc
		echo "launchCommand=$launchCommand # By_alaterm_installer." >> .bashrc
	fi
	if [ ! -f "$PREFIX/bin/$launchCommand" ] ; then
		grep alaterm_installer .bashrc >/dev/null 2>&1
		if [ "$?" -ne 0 ] ; then
			cp "$alatermTop/$launchCommand" "$PREFIX/bin" 2>/dev/null
			if [ "$?" -ne 0 ] ; then
				echo "WARNING. Did not find backup copy of alaterm launch command."
				echo "To restore alaterm, re-run:  bash 00-alaterm.bash install"
				echo "Whether that takes a minute, or much longer, is unclear."
			else
				echo -e "\e[1;92mRestoring alaterm to renewed Termux."
				echo -e "Only takes a minute. May require Termux update...\e[0m"
				sleep 3
				needem=""
				hash proot >/dev/null 2>&1
				[ "$?" -ne 0 ] && needem=proot
				hash wget >/dev/null 2>&1
				[ "$?" -ne 0 ] && needem+=" wget"
				if [ "$needem" != "" ] ; then
					pkg update
					pkg install $needem # No quotes.
				fi
			fi
			echo -e "\e[1;92mDONE.\e[0m You may now launch alaterm. Command: $launchCommand"
		fi
	fi
}


if [ "$nextPart" -ge 8 ] ; then # This part repeats, if necessary.
	cd "$hereiam"
	source fixexst-scripts.bash
	cd "$alatermTop/usr/local/scripts"
	create_compileLibde265
	chmod 755 compile-libde265
	create_compileLibmad
	chmod 755 compile-libmad
	create_compileLibmpeg2
	chmod 755 compile-libmpeg2
	create_autoremove
	chmod 755 autoremove
	cd "$alatermTop"
	start_launchCommand
	finish_launchCommand
	chmod 755 "$launchCommand"
	cp "$launchCommand" "$PREFIX/bin"
	grep alaterm ~/.bashrc >/dev/null 2>&1 # In Termux home.
	if [ "$?" -ne 0 ] ; then
		echo -e "echo \"To launch alaterm, command:  $launchCommand\n\"" >> ~/.bashrc
	fi
	cd "$alatermTop/usr/bin"
	create_fakeLaunch
	chmod 755 "$launchCommand" # Not the real one.
	cd "$HOME" # Termux home
	ensure_noTVNC
	restore_launchCommand
	cd "$hereiam"
	if [[ ! "$hereiam" =~ TAexp ]] ; then
		for nn in 01 02 03 04 05 06 07 08
		do
			rm -f "$nn-alaterm.bash"
		done
	fi
	echo -e "\n\e[1;92mDONE. To launch alaterm, command:  $launchCommand.\e[0m\n"
	let nextPart=9
	echo "let scriptRevision=5" >> "$alatermTop/status"
	echo "let nextPart=9" >> "$alatermTop/status"
fi



