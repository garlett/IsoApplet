@echo off

set path=%path%;"C:\Program Files\OpenSC Project\OpenSC\tools"
set reader=Virtual Smart Card Architecture Virtual PCD 0
set simulator=jcardsim-3.0.4-SNAPSHOT.jar
set simulator=jcardsim-3.0.5-SNAPSHOT.jar
set applet_base=IsoApplet3\src
set applet_path=%applet_base%\xyz\wendland\javacard\pki\isoapplet
rem set jcmath=JCMathLib-master\applet\src\main\java\opencrypto\jcmathlib\*.java JCMathLib-master\applet\src\main\java\opencrypto\jcmathlib\curves\*.java
rem set OPENSC_DEBUG=999
rem goto :softHSM


C:
cd\Users\user\Desktop\virtualsmartcard-0.8_win64

set reader11=--slot-description "%reader%"
set reader15=-r "%reader%"



rem pre-requisites:
rem	OpenSC-0.24.0_win64.msi     ++ x32 ?
rem	jdk-21_windows-x64_bin.msi ?
rem	BixVReaderInstaller.msi
rem	BixVReader.cer ?
rem	jcardsim-3.0.5-SNAPSHOT.jar
rem	IsoApplet3 (gitclone)
rem 	in 'IsoApplet.java'  leave as this:   public static final boolean DEF_PRIVATE_KEY_IMPORT_ALLOWED = DEF_PRIVATE_KEY_EXPORT_ALLOWED = true;
rem	pnputil OR devcon -> extract https://download.microsoft.com/download/8/6/9/86925F0F-D57A-4BA4-8278-861B6876D78E/wdk/Installers/09844d1815314132979ed88093f49c6f.cab and rename



if exist jcardsim_isoapplet.cfg goto :ok_cfg
echo com.licel.jcardsim.card.applet.0.AID=F276A288BCFBA69D34F31001 >> jcardsim_isoapplet.cfg
echo com.licel.jcardsim.card.applet.0.Class=xyz.wendland.javacard.pki.isoapplet.IsoApplet >> jcardsim_isoapplet.cfg
echo com.licel.jcardsim.card.ATR=3B80800101 >> jcardsim_isoapplet.cfg
:ok_cfg


tasklist /fi "WINDOWTITLE eq simulator" 2>NUL | find /I "java.exe" >NUL
if "%ERRORLEVEL%"=="0" goto :applet_running

echo ***************************
echo ******* restarting ********
echo ***************************

devcon.exe disable *Bix*
devcon.exe enable *Bix*
rem pnputil /disable-device  ?? "USB\VID_08E6&PID_3437\5&E57B0DF&0&6"
rem pnputil /enable-device  


echo ***************************
echo ******* compilation *******
echo ***************************

 del %applet_path%\*.class

 javac -cp %simulator% -Xlint:deprecation %applet_path%\*.java %jcmath%
 if "%ERRORLEVEL%"=="1" pause
echo ***************************
echo ***** starting applet *****
echo ***************************

 start /min "simulator" java -cp %applet_base%;%simulator% com.licel.jcardsim.remote.BixVReaderCard jcardsim_isoapplet.cfg

ping 0.0.0.0 >NUL
tasklist /fi "WINDOWTITLE eq simulator" 2>NUL | find /I "java.exe" >NUL
if "%ERRORLEVEL%"=="1" exit
 
:applet_running

echo ***************************
echo ****** send card apdu *****
echo ***************************

 opensc-tool %reader15% --send-apdu 80b800001a0cf276a288bcfba69d34f310010cf276a288bcfba69d34f3100100

echo ***************************
echo ***** formating card  *****
echo ***************************

 pkcs15-init %reader15% --create-pkcs15 --so-pin 1234 --so-puk 1234567890123456 --serial 123456789a123456789b123456789c12 --profile pkcs15+onepin
 
rem echo ***************************
rem echo ******* setting pin  ******
rem echo ***************************
rem  pkcs15-init %reader15% --store-pin --so-pin 1234 --so-puk 1234567890123456 --pin 1234 --puk 1234567890123456

echo ***************************
echo ****** importing pfx ******
echo ***************************

 pkcs15-init %reader15% --store-private-key ekey_cert_ca.pfx --id 46 -f PKCS12 --auth-id 01 --passphrase Senha123 --pin 1234

echo ***************************
echo ****** dumping list *******
echo ***************************

 pkcs15-tool %reader15% --dump

echo ***************************
echo ***** Cert Propagation ****
echo ***************************

rem C:\Windows\SysWOW64\certutil.exe -scinfo
rem   currently must manually add certificate when certutil shows it, because Provider must be smart card


echo ***************************
echo *** Export Certificate ****
echo ***************************


 rem cert/pubkey
 pkcs11-tool.exe %reader11% --id 46 --login --pin 1234 --read-object --type cert --output-file cert.cer

 rem not found: secrkey/data
 rem not allowed: privkey 	pkcs11-tool.exe %reader11% --id 46 --login --pin 1234 --read-object --type privkey --output-file export.key

 rem get priv key via multiple apdu
 opensc-tool %reader15% --send-apdu 002000011031323334000000000000000000000000 --send-apdu 00CA3F0000 --send-apdu 00CA3F0100 --send-apdu 00CA3F0200 --send-apdu 00CA3F0300 --send-apdu 00CA3F0400 --send-apdu 00CA3F0500 > key.txt
rem 00 class   CA get data   3F FF p1 get private key 00 key offset block 00 data length
rem 		69	82	E	Security condition not satisfied.
rem 		69	85	E	Conditions of use not satisfied.
rem 		6F	00	E	Command aborted – more exact diagnosis not possible (e.g., operating system error).
rem 		00	01		ram_buf out of bounds
rem 		00	03		APDUException.BUFFER_BOUNDS

cmd
exit



echo " ***********  key.txt to _key.cer"
cat key.txt | grep -v '^Sending: \|^Received ' | cut -d' ' -f1-16 | xxd -r -p > _key.cer

echo " ***********  _key.cer to _key.pem"
openssl rsa -inform der -in _key.cer -out _key.pem

echo " *********** cert.cer to _cert.pem"
openssl x509 -inform der -in cert.cer -out _cert.pem

echo " ********** pem to pfx"
openssl pkcs12 -export -out _exported_key_cert.pfx -in _cert.pem -inkey _key.pem












:openSC_pkcs11
rem pkcs11-tool.exe --read-object --type privkey --id 01 -l --pin 1234
https://github.com/OpenSC/OpenSC/blob/e2b1fb81e0e1339eebaa36fb90635e03f69d4da3/src/tools/pkcs11-tool.c#L4088
https://github.com/OpenSC/OpenSC/pull/1393


:openSC_pkcs15-tool_export-cert
https://github.com/OpenSC/OpenSC/issues/1522
https://github.com/OpenSC/OpenSC/blob/master/src/pkcs15init/pkcs15-isoApplet.c#L783
https://github.com/OpenSC/OpenSC/blob/master/src/pkcs15init/pkcs15-cflex.c#L938
rem  outputs hex pubkey, windows incompatible:  pkcs15-tool %reader15% --read-public-key 46 --auth-id 01 --output test.key


:openssl
rem extract as pem: ekey and certs 
 openssl pkcs12 -in certs.pfx -nocerts -out pem_ekey.key
 openssl pkcs12 -in certs.pfx -clcerts -nokeys -out pem_cert.key
rem decrypt ekey
 openssl rsa -in pem_ekey.key -out pem_key.key
rem convert pem_key to der_key
 openssl rsa -in pem_key.key -out der_key.key -outform der


:softHSM
rem https://github.com/opendnssec/SoftHSMv2/issues/597

"C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\bin\softhsm2-util.exe" --init-token --slot 0 --label "My token 1"

pkcs11-tool.exe -v --module "C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\lib\softhsm2-x64.dll" -l --pin 1234 --write-object cerj.key --type privkey --id 2222
pkcs11-tool.exe -v --module "C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\lib\softhsm2-x64.dll" -l --pin 1234 --write-object cert.crt --type cert --id 2222


"C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\bin\softhsm2-util.exe" --show-slots

pkcs11-tool --module "C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\lib\softhsm2-x64.dll" --show-info

pkcs11-tool --module "C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\lib\softhsm2-x64.dll" --list-objects

C:\Windows\SysWOW64\certutil.exe -csplist

cmd
exit
