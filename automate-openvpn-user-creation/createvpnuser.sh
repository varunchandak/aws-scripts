#!/bin/bash

SCRIPT_NAME=$(basename $0)
usage () {
echo '
Usage: '"$SCRIPT_NAME"' "OpenVPN User" [To Email ID (without spaces)]

E.g.
'"$SCRIPT_NAME"' anonymous someone@somewhere.com'
}

if [ "$#" -ne 2 ]
then
        usage
else

USER_NAME="$1"
USERPASSWD="$(cat /dev/urandom| tr -dc 'a-zA-Z0-9-_@#'|fold -w 10 | head -n 1)"
EMAIL_ID="$2"
#Adding username
useradd "$USER_NAME"

#Changing password
echo "$USER_NAME:$USERPASSWD" | chpasswd

#Generating Key and Crt for user
cd /etc/openvpn/easy-rsa/
./easyrsa build-client-full "$USER_NAME" nopass

#Gathering credentials
echo "
Username: $USER_NAME
Password: $USERPASSWD
" > credentials.txt

#Generating OVPN file
sed -e '/^cert/c\cert '"$USER_NAME"'.crt' -e '/^key/c\key '"$USER_NAME"'.key' /root/openvpn/openvpn.ovpn > openvpn_"$USER_NAME".ovpn

#Zipping the files:
zip -j -r /root/generated_openvpn_users/"$USER_NAME"_openvpn_files.zip /etc/openvpn/easy-rsa/pki/private/"$USER_NAME".key /etc/openvpn/easy-rsa/pki/issued/"$USER_NAME".crt credentials.txt /etc/openvpn/ca.crt openvpn_"$USER_NAME".ovpn

#Going into temp
cd /root/generated_openvpn_users/

#Sending email
echo "$USER_NAME OpenVPN Config Files" | mutt -e 'my_hdr From:sender@somewhere.com' -a /root/generated_openvpn_users/"$USER_NAME"_openvpn_files.zip -s "$USER_NAME OpenVPN Config Files" -- "$EMAIL_ID"
echo "Waiting 15 seconds"
sleep 15
fi
