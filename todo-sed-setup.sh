#!/bin/bash
set -e

clear && sudo ./sedutil-cli --help
echo ''
echo ''
echo ''

echo 'Type password:'
read ppp

echo 'Once again, please:'
read ppp2

echo 'And once more, just to be ABSOLUTELY sure:'
read ppp3

if [ -n "$ppp" ] && [ "$ppp" = "$ppp2" ] && [ "$ppp" = "$ppp3" ]; then
	echo 'OK, passwords match'
else
	echo 'WRONG: passwords mismatch or empty'
	exit 1
fi

echo ''
echo 'Device:'
read ddd

echo ''
echo 'PSID:'
read psid

echo ''
echo 'Checking device...'
sudo ./sedutil-cli --isValidSED "$ddd"

echo ''
echo ''
echo ''
echo 'About to FULLY CLEAR and reset the drive to factory settings (removing __ALL__ data on it):'
echo "    $ddd"
echo 'Last chance to stop (Ctrl+C)'
echo ''
echo 'Continue?'
read

echo ''
echo "sudo ./sedutil-cli --PSIDrevert '$psid' '$ddd'"
sudo ./sedutil-cli --PSIDrevert "$psid" "$ddd"

echo ''
echo "sudo ./sedutil-cli --initialSetup <password> '$ddd'"
sudo ./sedutil-cli --initialSetup "$ppp" "$ddd"

echo ''
echo "sudo ./sedutil-cli --enableLockingRange 0 <password> '$ddd'"
sudo ./sedutil-cli --enableLockingRange 0 "$ppp2" "$ddd"

echo ''
echo "sudo ./sedutil-cli --setLockingRange 0 lk <password> '$ddd'"
sudo ./sedutil-cli --setLockingRange 0 lk "$ppp3" "$ddd"

echo ''
echo "sudo ./sedutil-cli --setMBRDone off <password> '$ddd'"
sudo ./sedutil-cli --setMBRDone off "$ppp" "$ddd"

echo ''
echo "sudo ./sedutil-cli --loadPBAimage <password> ~/_GIT/sedutil-manjaro-pba/SEDPBA-1.20-Manjaro-25.0.10.img '$ddd'"
sudo ./sedutil-cli --loadPBAimage "$ppp2" ~/_GIT/sedutil-manjaro-pba/SEDPBA-1.20-Manjaro-25.0.10.img "$ddd"

echo ''
echo "sudo ./sedutil-cli --setMBRDone on <password> '$ddd'"
sudo ./sedutil-cli --setMBRDone on "$ppp3" "$ddd"

echo ''
echo ''
echo ''
echo 'SED setup complete for:'
echo "    $ddd"
echo 'Done.'
