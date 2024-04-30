@echo off

set reader=-r "Virtual Smart Card Architecture Virtual PCD 0"

set path=%path%;"C:\Program Files\OpenSC Project\OpenSC\tools"

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
rem 	in 'IsoApplet.java'  leave as this:   public static final boolean DEF_PRIVATE_KEY_IMPORT_ALLOWED = true;
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

 javac -cp jcardsim-3.0.5-SNAPSHOT.jar -Xlint:deprecation IsoApplet3\src\xyz\wendland\javacard\pki\isoapplet\*.java

echo ***************************
echo ***** starting applet *****
echo ***************************

 start /min "simulator" java -cp IsoApplet3\src;jcardsim-3.0.5-SNAPSHOT.jar com.licel.jcardsim.remote.BixVReaderCard jcardsim_isoapplet.cfg

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

 certutil.exe -scinfo
 rem   currently must manually add certificate, because Provider must be smart card


echo ***************************
echo *** Export Certificate ****
echo ***************************


cmd
exit



:openSC_pkcs11
rem pkcs11-tool.exe --read-object --type privkey --id 01 -l --pin XXXXXX
https://github.com/OpenSC/OpenSC/blob/e2b1fb81e0e1339eebaa36fb90635e03f69d4da3/src/tools/pkcs11-tool.c#L4088
https://github.com/OpenSC/OpenSC/pull/1393

:openSC_pkcs15-tool_export-cert
https://github.com/OpenSC/OpenSC/issues/1522
https://github.com/OpenSC/OpenSC/blob/master/src/pkcs15init/pkcs15-isoApplet.c#L783
https://github.com/OpenSC/OpenSC/blob/master/src/pkcs15init/pkcs15-cflex.c#L938



:isoapplet
rem https://github.com/philipWendland/IsoApplet/blob/main/src/xyz/wendland/javacard/pki/isoapplet/IsoApplet.java#L287
public void process(APDU apdu)
	private void processGetData(APDU apdu)
		... look at private void processPutData(APDU apdu)
		insert case -> find key export constant
		if( ! pin.isValidated() ) {  ISOException.throwIt(ISO7816.SW_SECURITY_STATUS_NOT_SATISFIED);         }
		if( ! DEF_PRIVATE_KEY_EXPORT_ALLOWED) { ISOException.throwIt(SW_COMMAND_NOT_ALLOWED_GENERAL); } 
		exportPrivateKey(apdu);
		private void importRSAkey(byte[] buf, short bOff, short bLen) throws ISOException, NotFoundException, InvalidArgumentsException {




:softHSM


softhsm2-util.exe --init-token --slot 0 --label "My token 1"

openssl pkcs12 -in cert.pfx -nocerts -out cert.key
openssl pkcs12 -in cert.pfx -clcerts -nokeys -out cert.crt

pkcs11-tool.exe -v --module softhsm2-x64.dll -l --pin 1234 --write-object cerj.key --type privkey --id 2222
pkcs11-tool.exe -v --module softhsm2-x64.dll -l --pin 1234 --write-object cert.crt --type cert --id 2222



softhsm2-util.exe --show-slots

pkcs11-tool --module softhsm2-x64.dll --show-info

pkcs11-tool --module softhsm2-x64.dll --list-objects

certutil.exe -csplist




cmd
exit

