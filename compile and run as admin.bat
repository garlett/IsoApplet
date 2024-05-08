@echo off

set path=%path%;"C:\Program Files\OpenSC Project\OpenSC\tools"
set reader=-r "Virtual Smart Card Architecture Virtual PCD 0"
set simulator=jcardsim-3.0.4-SNAPSHOT.jar
set simulator=jcardsim-3.0.5-SNAPSHOT.jar
set applet_base=IsoApplet3\src
set applet_path=%applet_base%\xyz\wendland\javacard\pki\isoapplet


C:
cd\Users\user\Desktop\virtualsmartcard-0.8_win64

rem goto :softHSM



rem pre-requisites:
rem	OpenSC-0.24.0_win64.msi     ++ x32 ?
rem	jdk-21_windows-x64_bin.msi?
rem	BixVReader.cer?
rem	BixVReaderInstaller.msi
rem	jcardsim-3.0.5-SNAPSHOT.jar
rem	IsoApplet3 -> gitclone
rem 	in 'IsoApplet.java'  leave as this:   public static final boolean DEF_PRIVATE_KEY_IMPORT_ALLOWED = DEF_PRIVATE_KEY_EXPORT_ALLOWED = true;
rem	pnputil OR devcon -> extract https://download.microsoft.com/download/8/6/9/86925F0F-D57A-4BA4-8278-861B6876D78E/wdk/Installers/09844d1815314132979ed88093f49c6f.cab and rename

rem jcardsim_isoapplet.cfg:
rem	com.licel.jcardsim.card.applet.0.AID=F276A288BCFBA69D34F31001
rem	com.licel.jcardsim.card.applet.0.Class=xyz.wendland.javacard.pki.isoapplet.IsoApplet
rem	com.licel.jcardsim.card.ATR=3B80800101




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

 javac -cp %simulator% -Xlint:deprecation %applet_path%\*.java

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

 opensc-tool %reader% --send-apdu 80b800001a0cf276a288bcfba69d34f310010cf276a288bcfba69d34f3100100

echo ***************************
echo ***** formating card  *****
echo ***************************

 pkcs15-init %reader% --create-pkcs15 --so-pin 1234 --so-puk 1234567890123456 --serial 123456789a123456789b123456789c12 --profile pkcs15+onepin
 
rem echo ***************************
rem echo ******* setting pin  ******
rem echo ***************************
rem  pkcs15-init %reader% --store-pin --so-pin 1234 --so-puk 1234567890123456 --pin 1234 --puk 1234567890123456

echo ***************************
echo ****** importing pfx ******
echo ***************************

 pkcs15-init %reader% --store-private-key certs.pfx --id 46 -f PKCS12 --auth-id 01 --passphrase Senha123 --pin 1234

echo ***************************
echo ****** dumping list *******
echo ***************************

 pkcs15-tool %reader% --dump

echo ***************************
echo ***** Cert Propagation ****
echo ***************************

rem C:\Windows\SysWOW64\certutil.exe -scinfo
rem   currently must manually add certificate when certutil shows it, because Provider must be smart card


echo ***************************
echo *** Export Certificate ****
echo ***************************


rem 00 class   CA get data   3F FF p1 p2 get private opcode   00 data length
 opensc-tool %reader% --send-apdu 00CA3FFF00
rem response:		69	82	E	Security condition not satisfied.
rem response:		69	85	E	Conditions of use not satisfied.
rem response:		6F	00	E	Command aborted – more exact diagnosis not possible (e.g., operating system error).
rem response:		00	01		? ram_buf out of bounds
rem response:		00	03		? APDUException.BUFFER_BOUNDS
rem 	pkcs15-tool %reader% --verify-pin

cmd
exit





:openSC_pkcs11
rem pkcs11-tool.exe --read-object --type privkey --id 01 -l --pin 1234
https://github.com/OpenSC/OpenSC/blob/e2b1fb81e0e1339eebaa36fb90635e03f69d4da3/src/tools/pkcs11-tool.c#L4088
https://github.com/OpenSC/OpenSC/pull/1393

:openSC_pkcs15-tool_export-cert
https://github.com/OpenSC/OpenSC/issues/1522
https://github.com/OpenSC/OpenSC/blob/master/src/pkcs15init/pkcs15-isoApplet.c#L783
https://github.com/OpenSC/OpenSC/blob/master/src/pkcs15init/pkcs15-cflex.c#L938



:softHSM

openssl pkcs12 -in cert.pfx -nocerts -out cert.key
openssl pkcs12 -in cert.pfx -clcerts -nokeys -out cert.crt

"C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\bin\softhsm2-util.exe" --init-token --slot 0 --label "My token 1"

pkcs11-tool.exe -v --module "C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\lib\softhsm2-x64.dll" -l --pin 1234 --write-object cerj.key --type privkey --id 2222
pkcs11-tool.exe -v --module "C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\lib\softhsm2-x64.dll" -l --pin 1234 --write-object cert.crt --type cert --id 2222



"C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\bin\softhsm2-util.exe" --show-slots

pkcs11-tool --module "C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\lib\softhsm2-x64.dll" --show-info

pkcs11-tool --module "C:\Program Files (x86)\OpenSC Project\SoftHSMv2.5\lib\softhsm2-x64.dll" --list-objects

C:\Windows\SysWOW64\certutil.exe -csplist


cmd
exit

