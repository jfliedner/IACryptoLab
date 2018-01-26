#!/bin/bash

#verifying number of arguments
if [ $# -ne 5 ]; then
	echo "Incorrect number of arguments"
	exit
fi

FLAG=$1	#type of flag
FIRST_KEY=$2 #first key given
SECOND_KEY=$3 #second key given
FILE_A=$4 #first file name/file
FILE_B=$5 #second file name/file


#encryption
if [ $FLAG == "-e" ]; then
	#getting the AES key and IV
	openssl rand 16 | hexdump -e '16/1 "%02x" "\n"' > /tmp/key
	openssl rand 16 | hexdump -e '16/1 "%02x" "\n"' > /tmp/iv
	#opening files from above and storing them into variables
	AES_KEY="$(cat /tmp/key)"
	IV_KEY="$(cat /tmp/iv)"
	
	#creating the hash of the plaintext
	openssl dgst -sha256 $FILE_A | awk {'print $2'} > /tmp/encrypt_hash
	if [ $? -ne 0 ]; then
		echo "Error with creating hash of plaintext"
		exit
	fi

	#signing for authenticity
	openssl dgst -sha256 -sign $SECOND_KEY -out /tmp/sign $FILE_A
	if [ $? -ne 0 ]; then
		echo "Error with signing plaintext"
		exit
	fi

	#encrypting the data using AES-128
	openssl aes-128-cbc -K $AES_KEY -iv $IV_KEY -e -in $FILE_A -out /tmp/encrypted
	if [ $? -ne 0 ]; then
		echo "Error with encrypting data"
		exit
	fi

	#encrypting the AES key and IV using RSA
	openssl rsautl -encrypt -inkey $FIRST_KEY -pubin -in /tmp/key -out /tmp/AES_PRIV.txt
	if [ $? -ne 0 ]; then
		echo "Error with encrypting AES key"
		exit
	fi

	openssl rsautl -encrypt -inkey $FIRST_KEY -pubin -in /tmp/iv -out /tmp/AES_PRIV_IV.txt
	if [ $? -ne 0 ]; then
		echo "Error with encrypting IV"
		exit
	fi
	
	#zipping the files together
	zip -r $5 /tmp/encrypted /tmp/AES_PRIV.txt /tmp/AES_PRIV_IV.txt /tmp/encrypt_hash /tmp/sign
	if [ $? -ne 0 ]; then
		echo "Error with zipping"
		exit
	fi
#decryption	
elif [ $FLAG == "-d" ]; then
	#unzipping
	unzip -o $FILE_A
	if [ $? -ne 0 ]; then
		echo "Error with unzipping"
		exit
	fi

	#retrieving AES key and IV through decryption of RSA
	AES_KEY="$(openssl rsautl -decrypt -inkey $FIRST_KEY -in /tmp/AES_PRIV.txt)"
	if [ $? -ne 0 ]; then
		echo "Error with retrieving AES key"
		exit
	fi

	IV_KEY="$(openssl rsautl -decrypt -inkey $FIRST_KEY -in /tmp/AES_PRIV_IV.txt)"
	if [ $? -ne 0 ]; then
		echo "Error with retireving IV"
		exit
	fi

	#decrypting the data using AES key and IV retrieved
	openssl aes-128-cbc -K $AES_KEY -iv $IV_KEY -d -in /tmp/encrypted -out $FILE_B
	if [ $? -ne 0 ]; then
		echo "Error with decrypting"
		exit
	fi

	#verifying the authenticity through signing
	openssl dgst -sha256 -verify $SECOND_KEY -signature /tmp/sign $FILE_B | grep 'Verified OK' &> /dev/null
	#verifying signature verify command outputted "Verified OK"
	if [ $? -ne 0 ]; then
		echo "Bad signature. Cannot verify authenticity"
	fi

	#getting the hash of the decrypted plaintext
	HASH_DECRYPT="$(openssl dgst -sha256 $FILE_B | awk {'print $2'})"
	if [ $? -ne 0 ]; then
		echo "Error with hashing decrypted plaintext"
		exit
	fi

	#getting the hash from the encryption
	HASH_ENCRYPT="$(cat /tmp/encrypt_hash)"
	if [ $? -ne 0 ]; then
		echo "Error with opening /tmp/encrypt_hash"
		exit
	fi

	#comparing to see if valid
	if [ "$HASH_ENCRYPT" != "$HASH_DECRYPT" ]; then
	 	echo "Unable to verify hash, cannot verify integrity"
	fi
	
#not a valid flag	
else
    	echo "Incorrect command line arguments"
	exit
	
fi