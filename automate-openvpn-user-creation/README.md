Normally, what we do is:

* use `easy-rsa` commandline tool to generate the `.crt`, `.key` files and the `.ovpn` file,
* copy the required files to the desktop using **WinSCP** or **FileZilla** or any other software.

The above seems very tedious task to perform manually everytime a user ID has to be created. In this blog post, I'll share a <u>Shell Script</u> to automate this process, as well as send an email with a `.zip` file attached, containing all the relevant files.

<!--more-->

I am assuming the following is already in place:

* **OpenVPN Server** on Linux (Version `OpenVPN 2.3.6 x86_64-redhat-linux-gnu`)
* **Easy RSA 3**
* OS: `Amazon Linux AMI 2016.03`

The script uses the following command line  tools to work:

* **zip** (to zip all the necessary files)
* **mutt** (to send email with attachment)
---
# Usage and Working

### Usage:

`./createvpnuser.sh "OpenVPN User" [To Email ID (without spaces)]`

---

### Working:

The script works in the following way:

1. The script takes 2 arguments for userID and email address, respectively.
2. Password of the user is generated using `/dev/urandom`, which is a *pseudo random number generator*.
3. `./easyrsa build-client-full <USERID> nopass` command is used to generate the required files.
4. The files are zipped to a predefined location.
5. An email is sent to address given in **Step 1**.

# Full Script

```sh
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
```

# List of Files included in zip

1. `<USERID>.key`
2. `<USERID>.crt`
3. `credentials.txt`
4. `ca.crt`
5. `openvpn_<USERID>.ovpn`

# Notes

1. The above works for me. Cannot guarantee for you.
2. Go through the script **carefully** before executing.
3. You can download the `easyrsa` file from Github.
4. Happy to help in any issues.
