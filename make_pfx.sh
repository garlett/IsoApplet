rm _*

echo " ***********  key.txt to _key.cer"
cat key.txt | grep -v '^Sending: \|^Received ' | cut -d' ' -f1-16 | xxd -r -p > _key.cer
# dd conv=swab if=_key.cer of=_key.cer

echo " ***********  _key.cer to _key.pem"
openssl rsa -inform der -in _key.cer -out _key.pem


echo " ********** key.pem to file "
openssl asn1parse -in _key.pem > _pem_key__parsed.txt
while read line; do
    arr+=("$line")
done < _pem_key__parsed.txt
    

echo " *********** calculating p*q and modinverve  "

m=$( echo " ibase=16; obase=10; ${arr[5]:46} * ${arr[6]:46}" | bc ) 
d=$( echo "
	e=65537;

	ibase=16;
	obase=10;

p=${arr[5]:46}
q=${arr[6]:46}
	phi=(p - 1) * (q - 1);
 
	define mi(a, n){
		i = n;
		v = 0;
		d = 1;

		while (a > 0)
		{
			t = i / a;
			x = a;
			a = i % x;
			i = x;
			x = d;
			d = v - t * x;
			v = x;
		}
		v = v % n;
		if (v < 0)
		v = (v + n) % n;
		return v;
	}

	mi(e, phi)
	" | bc )



echo " ***********  _genconf.txt to _key.pem"

echo "
asn1=SEQUENCE:rsa_key

[rsa_key]
version=INTEGER:0
modulus=INTEGER:0x${m//\\$'\n'/}
pubExp=INTEGER:65537
privExp=INTEGER:0x${d//\\$'\n'/}
p=INTEGER:0x${arr[5]:46}
q=INTEGER:0x${arr[6]:46}
e1=INTEGER:0x${arr[7]:46}
e2=INTEGER:0x${arr[8]:46}
coeff=INTEGER:0x${arr[9]:47}
" > _genconf.txt

echo " ***********  _genconf.txt to _key2.cer"
openssl asn1parse -genconf _genconf.txt -out _key2.cer

echo " ***********  _key2.cer to _key.pem"
openssl rsa -inform der -in _key2.cer -out _key2.pem





echo " *********** cert.cer to _cert.pem"
openssl x509 -inform der -in cert.cer -out _cert.pem

echo " ********** pem to pfx"
openssl pkcs12 -export -out exported_key_cert.pfx -in _cert.pem -inkey _key2.pem && rm _*


